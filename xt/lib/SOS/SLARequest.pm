package SOS::SLARequest;
use NAP::policy 'class', 'tt';

=head1 NAME

SOS::SLARequest

=head1 DESCRIPTION

An object that contains the logic for fulfilling an SLA request

=cut

with    'XTracker::Role::WithSchema',
        'XTracker::Role::AccessConfig';

# These are overriddable for ease of testing
has 'shipment_class_rs' => (
    is=>'ro',lazy=>1,default=>sub {shift->schema->resultset('SOS::ShipmentClass')},
);
has 'carrier_rs' => (
    is=>'ro',lazy=>1,default=>sub {shift->schema->resultset('SOS::Carrier')},
);
has 'country_rs' => (
    is=>'ro',lazy=>1,default=>sub {shift->schema->resultset('SOS::Country')},
);
has 'channel_rs' => (
    is=>'ro',lazy=>1,default=>sub {shift->schema->resultset('SOS::Channel')},
);
has 'processing_time_rs' => (
    is=>'ro',lazy=>1,default=>sub {shift->schema->resultset('SOS::ProcessingTime')},
);
has 'truck_departure_rs' => (
    is=>'ro',lazy=>1,default=>sub {shift->schema->resultset('SOS::TruckDeparture')},
);
has 'wms_priority_rs' => (
    is=>'ro',lazy=>1,default=>sub {shift->schema->resultset('SOS::WmsPriority')},
);
has 'system_time_zone' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        $self->get_config_var('DistributionCentre', 'timezone');
    },
);

use SOS::Shipment;
use DateTime;
use SOS::Exception::InvalidCountryCode;
use SOS::Exception::InvalidRegionCode;
use SOS::Exception::InvalidShipmentClassCode;
use SOS::Exception::InvalidCarrierCode;
use SOS::Exception::InvalidChannelCode;
use SOS::Exception::MissingNomDayComponent;
use SOS::Exception::NoTruckDepartureFound;
use MooseX::Params::Validate;

=head1 PUBLIC METHODS

=head2 get_sla_data

Fulfils an SLA request

All parameters required except where noted

 param - shipment_class_code : An SOS compatible Shipment Class code.
  This comes from the sos.shipment_class database table, 'api_code' column
 param - carrier_code : An SOS compatible carrier code
 param - country_code : An ISO-3166 two letter country code
 param - region_code : (Optional) Currently unused.
 param - selection_date_epoch : The date from which a truck departure time should be
  worked out from as UTC seconds from epoch . This is usually when an order was placed by
  the customer
 param - is_express : (Default = 0) If set to 1, the shipment will be prioritised as an
    'express' shipment
 param - is_eip : (Default = 0) If set to 1, the shipment will be prioritised as an
    'eip' shipment
 param - is_slow: (Default = 0) If set to 1, the shipment will be prioritised as an
    'slow' shipment
 param - is_full_sale: (Default = 0) If set to 1, the shipment will be prioritised as a
    'full_sale' shipment
 param - is_mixed_sale: (Default = 0) If set to 1, the shipment will be prioritised as a
    'mixed_sale' shipment

If a request is successful, the following parameters will be returned:
 return - sla_epoch : Target time in UTC seconds from epoch that the shippable should aim
  to be on a truck
 return - wms_deadline_epoch : Epoch time that should be used for sorting the shippable
  for selection/picking
 return - wms_initial_pick_priority : Integer value used for sorting the shippable for
  selection/picking
 return - wms_bump_pick_priority : Integer value used for sorting the shippable for
  selection/picking (may be undefined)
 return - wms_bump_deadline_epoch : Epoch that should be used for sorting the shippable
  for selection/picking (maybe undefined)
=cut

sub get_sla_data {
    my ($self, $raw_params) = @_;
    my $return = {};

    try {
        my %params = validated_hash([$raw_params],
            shipment_class_code     => { isa => 'Str' },
            carrier_code            => { isa => 'Str' },
            country_code            => { isa => 'Str' },
            region_code             => { isa => 'Str', optional => 1 },
            channel_code            => { isa => 'Str' },
            selection_date_epoch    => { isa => 'Int' },
            is_express              => { isa => 'Bool', default => 0 },
            is_eip                  => { isa => 'Bool', default => 0 },
            is_slow                 => { isa => 'Bool', default => 0 },
            is_mixed_sale           => { isa => 'Bool', default => 0 },
            is_full_sale            => { isa => 'Bool', default => 0 },
            # MooseX::Params::Validate uses caller_cv as a cache key
            # for the compiled validation constraints. 'try' takes a
            # coderef, that in this case is a garbage-collectable
            # anonymous sub that closes over some variables; since
            # it's a closure, it gets re-allocated every time. A new
            # sub (anonymous or not) created after this one is called
            # may well end up at the same memory address, thus
            # colliding in the MX:P:V cache; let's provide a hand-made
            # key to make sure we never collide
            MX_PARAMS_VALIDATE_CACHE_KEY => __FILE__.__LINE__,
        );

        my $shipment = $self->_validate_params_and_create_shipment(\%params);
        $return = $self->_get_return_datetime_data($shipment);

    } catch {
        $return->{error} = "$_";
    };

    return $return;
}

sub _validate_params_and_create_shipment {
    my ($self, $params) = @_;

    my $shipment_class = $self->shipment_class_rs->find({
        api_code => $params->{shipment_class_code}
    }) or SOS::Exception::InvalidShipmentClassCode->throw({
        shipment_class_code => $params->{shipment_class_code},
    });
    my $carrier = $self->carrier_rs->find({
        code => $params->{carrier_code},
    }) or SOS::Exception::InvalidCarrierCode->throw({
        carrier_code => $params->{carrier_code},
    });
    my $country = $self->country_rs->find({
        api_code => $params->{country_code},
    }) or SOS::Exception::InvalidCountryCode->throw({
        country_code => $params->{shipment_class_code},
    });
    my $region;
    if ($params->{region_code}) {
        $region = $country->search_related('regions', {
            api_code => $params->{region_code},
        })->first or SOS::Exception::InvalidRegionCode->throw({
            country_code    => $params->{country_code},
            region_code     => $params->{region_code}
        });
    }
    my $channel = $self->channel_rs->find({
        api_code => $params->{channel_code},
    }) or SOS::Exception::InvalidChannelCode->throw({
        channel_code => $params->{channel_code},
    });

    my $selection_datetime = DateTime->from_epoch(
        epoch       => $params->{selection_date_epoch},
        time_zone   => $self->system_time_zone()
    );

    return SOS::Shipment->new(
        shipment_class      => $shipment_class,
        carrier             => $carrier,
        selection_datetime  => $selection_datetime,
        country             => $country,
        ($region ? ( region => $region ) : () ),
        channel             => $channel,
        processing_time_rs  => $self->processing_time_rs(),
        wms_priority_rs     => $self->wms_priority_rs(),
        truck_departure_rs  => $self->truck_departure_rs(),
        is_express          => $params->{is_express},
        is_eip              => $params->{is_eip},
        is_slow             => $params->{is_slow},
        is_full_sale        => $params->{is_full_sale},
        is_mixed_sale        => $params->{is_mixed_sale},
    );
}


sub _get_return_datetime_data {
    my ($self, $shipment) = @_;

    my $sla_datetime = $shipment->get_sla_datetime();
    my $wms_deadline = $shipment->wms_deadline();

    my $bump_data = {};
    if (my $wms_bump_deadline = $shipment->wms_bump_deadline()) {
        $bump_data = {
            wms_bump_pick_priority      => $shipment->wms_bumped_priority(),
            wms_bump_deadline_epoch     => $wms_bump_deadline->epoch()
        };
    }

    return {
        sla_epoch                   => $sla_datetime->epoch(),
        wms_deadline_epoch          => $wms_deadline->epoch(),
        wms_initial_pick_priority   => $shipment->wms_initial_pick_priority(),

        # The extra 'bump' data may or may not be set, as not all shipments
        # can be 'bumped'
        %$bump_data
    };
}
