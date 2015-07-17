package XTracker::Role::SOS::Shippable;
use NAP::policy "tt", 'role';
with 'XTracker::Role::AccessConfig';
with 'XTracker::Role::WithSchema';

use Class::Load 'load_class';

=head1 NAME

XTracker::Role::SOS::Shippable

=head1 DESCRIPTION

A role for objects that allows them to aquire an SLA from the ShippingOptionService

=cut

has 'shipping_option_service' => (
    is      => 'ro',
    isa     => 'SOS::SLARequest',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my $service_class = $self->get_config_var('SOS', 'api_class');
        load_class($service_class);
        return $service_class->new();
    },
);

has 'is_sos_enabled' => (
    is      => 'ro',
    isa     => 'Bool',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->get_config_var('SOS', 'enabled');
    },
);

has 'emergency_sla_interval_in_minutes' => (
    is      => 'ro',
    isa     => 'Int',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->get_config_var('SOS', 'emergency_sla_interval_in_minutes');
    },
);

has 'emergency_sla_initial_pick_priority' => (
    is      => 'ro',
    isa     => 'Int',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->get_config_var('SOS', 'emergency_sla_initial_pick_priority');
    },
);

=head1 REQUIRED METHODS

=head2 get_shippable_requested_datetime

Should return a DateTime object that represents when the shippable was requested

=head2 get_shippable_nominated_day_datetime

If the shippable has a specific date and time when it should be arrive at its destination,
a DateTime should be returned by this method to represent that date and time. Otherwise
return undef

=head2 get_shippable_carrier

Return a XTracker::Schema::Result::Public::Carrier object for the carrier that should
deliver this shippable

=head2 get_shippable_country_code

Return an ISO-3166 two letter country code for the destination country

=head2 get_shippable_region_code

TODO: In future will be used to identify a specific destination region in the destination
country. For now just return undef

=head2 shippable_is_transfer

Return 1 if this shippable should be prioritised as a 'transfer' (or sample) shipment

=head2 shippable_is_rtv

Return 1 if this shippable should be prioritised as 'return to vendor'

=head2 shippable_is_staff

Return 1 if this shippable should be prioritised as for staff

=head2 shippable_is_premier_daytime

Return 1 if this shippable should be prioritised as premier daytime

=head2 shippable_is_premier_evening

Return 1 if this shippable should be prioritised as premier evening

=head2 shippable_is_premier_all_day

Return 1 if this shippable should be prioritised as premier all day

head2 shippable_is_nominated_day

Return 1 if this shippable should be prioritised as a non-premier nominated day shipment

=head2 shippable_is_express

Return 1 if this shippable should be prioritised as express

=head2 shippable_is_eip

Return 1 if this shippable should be prioritised as eip

=head2 shippable_is_slow

Return 1 if this shippable should be prioritised as slow

=head2 shippable_is_virtual_only

Return 1 if this shippable only contains virtual (electronic) items

=cut

requires qw/
    get_shippable_requested_datetime
    get_shippable_carrier
    get_shippable_channel
    get_shippable_country_code
    get_shippable_region_code
    shippable_is_transfer
    shippable_is_rtv
    shippable_is_staff
    shippable_is_nominated_day
    shippable_is_premier_daytime
    shippable_is_premier_evening
    shippable_is_premier_hamptons
    shippable_is_premier_all_day
    shippable_is_express
    shippable_is_eip
    shippable_is_slow
    shippable_is_virtual_only
    shippable_is_full_sale
    shippable_is_mixed_sale
/;

use XTracker::Constants qw/
    :sos_shipment_class
    :sos_carrier
    :sos_channel
/;
use XTracker::Constants::FromDB qw/
    :carrier
    :channel
    :business
/;

use NAP::XT::Exception::SOS::UnmappableCarrier;
use NAP::XT::Exception::SOS::UnmappableChannel;
use NAP::XT::Exception::SOS::NoTimeZone;
use NAP::XT::Exception::SOS::IncompatibleShippable;
use DateTime;
use Readonly;
use MooseX::Params::Validate;

=head2 get_sla_data

Make a request to the SOS service to get an SLA for the shippable, an earliest
selection_time, and prioritisation data that should be passed on to the WMS system that
handles this DCs picking

Note regarding below return values: Either both $wms_bump_pick_priority and
$wms_deadline_datetime will be defined or neither. Never just one or the other.

 param - force_call : (Default = 0) If set to 1, this will force the call to SOS even
    if the current config suggests that the shipment is incompatible. (This has been
    added so that we can get the priority values for shipments before SOS is being enabled
    in general).

 return - $sla_cutoff_datetime : DateTime that represents the SLA cutoff time
 return - $wms_initial_pick_priority : An integer that represents the shippable's initial
    picking priority value within the WMS system
 return - $wms_deadline_datetime : Datetime that informs the WMS system by what time this
    shippable is expected to have been picked by
 return - $wms_bump_pick_priority : If set, this integer represents the picking priority
    value that the shippable should be 'bumped' to within the WMS system if the
    $wms_deadline_datetime (below) is reached.
 return - $wms_bump_deadline_datetime : If set, the shippable's pick priority within the
    WMS system will be bumped to the $wms_bump_pick_priority value (above) when this
    DateTime is reached

=cut
sub get_sla_data {
    my ($self, $force_call) = validated_list(\@_,
        force_call => { isa => 'Bool', default => 0 },
    );

    if (!$force_call) {
        # Ensure that the shippable is compatible with the current SOS configuration
        NAP::XT::Exception::SOS::IncompatibleShippable->throw()
            unless $self->use_sos_for_sla_data();
    }

    my $order_placed_datetime = $self->get_shippable_requested_datetime();

    # Must not have 'Floating' timezone
    NAP::XT::Exception::SOS::NoTimeZone->throw()
        if $order_placed_datetime->time_zone->isa('DateTime::TimeZone::Floating');

    my $region_code = $self->get_shippable_region_code();

    my $shipping_option_data = $self->shipping_option_service->get_sla_data({
        shipment_class_code => $self->_get_shippable_shipment_class_code(),
        carrier_code        => $self->_get_shippable_carrier_code(),
        channel_code        => $self->_get_shippable_channel_code(),
        country_code        => $self->get_shippable_country_code(),
        ( $region_code ? (region_code => $region_code) : () ),
        selection_date_epoch=> $order_placed_datetime->epoch(),
        is_express          => $self->shippable_is_express(),
        is_eip              => $self->shippable_is_eip(),
        is_slow             => $self->shippable_is_slow(),
        is_full_sale        => $self->shippable_is_full_sale(),
        is_mixed_sale        => $self->shippable_is_mixed_sale(),
    });

    if ($shipping_option_data->{error}) {
        # Gadzooks! Something went wrong :(
        die $shipping_option_data->{error};
    }

    # Transform our return data in to datetime objects
    my $sla_cutoff_datetime = DateTime->from_epoch(
        epoch       => $shipping_option_data->{sla_epoch},
        time_zone   => 'UTC',
    );
    my $wms_deadline_datetime = DateTime->from_epoch(
        epoch       => $shipping_option_data->{wms_deadline_epoch},
        time_zone   => 'UTC',
    );
    my $wms_bump_deadline_datetime;
    if ($shipping_option_data->{wms_bump_deadline_epoch}) {
        $wms_bump_deadline_datetime = DateTime->from_epoch(
            epoch => $shipping_option_data->{wms_bump_deadline_epoch},
        );
    }
    return (
        $sla_cutoff_datetime,
        $shipping_option_data->{wms_initial_pick_priority},
        $wms_deadline_datetime,
        $shipping_option_data->{wms_bump_pick_priority},
        $wms_bump_deadline_datetime
    );
}

sub _get_shippable_shipment_class_code {
    my ($self) = @_;

    # RTV shipments are treated as transfer shipments
    return $SOS_SHIPMENT_CLASS__TRANSFER
        if $self->shippable_is_transfer() || $self->shippable_is_rtv();

    # NOTE: For some reason transfer shipments are being processed as 'virtual' shipments.
    # I can't work out why this is happening so for now we'll make the 'Transfer' check
    # first to side-step the bug. Needs proper investigation.

    # If a shippable only has virtual items in it then we use the 'Email' class
    return $SOS_SHIPMENT_CLASS__EMAIL if $self->shippable_is_virtual_only();

    return $SOS_SHIPMENT_CLASS__STAFF if $self->shippable_is_staff();

    return $SOS_SHIPMENT_CLASS__PREMIER_DAYTIME if $self->shippable_is_premier_daytime();
    return $SOS_SHIPMENT_CLASS__PREMIER_EVENING if $self->shippable_is_premier_evening();
    return $SOS_SHIPMENT_CLASS__PREMIER_ALL_DAY if $self->shippable_is_premier_all_day();
    return $SOS_SHIPMENT_CLASS__PREMIER_HAMPTONS if $self->shippable_is_premier_hamptons();

    return $SOS_SHIPMENT_CLASS__NOMDAY if $self->shippable_is_nominated_day();

    # Assume standard if it doesn't fit one of the other classes
    return $SOS_SHIPMENT_CLASS__STANDARD;
}

Readonly my %XT_CARRIER_TO_SOS_CARRIER_MAP => {
    $CARRIER__UNKNOWN       => $SOS_CARRIER__NAP,
    $CARRIER__UPS           => $SOS_CARRIER__UPS,
    $CARRIER__DHL_EXPRESS   => $SOS_CARRIER__DHL,
    $CARRIER__DHL_GROUND    => $SOS_CARRIER__DHL,
};

sub _get_shippable_carrier_code {
    my ($self) = @_;

    my $carrier = $self->get_shippable_carrier();

    my $carrier_id = $carrier->id();
    NAP::XT::Exception::SOS::UnmappableCarrier->throw({
        carrier => $carrier,
    }) unless $XT_CARRIER_TO_SOS_CARRIER_MAP{$carrier_id};

    return $XT_CARRIER_TO_SOS_CARRIER_MAP{$carrier_id};
}

Readonly my %XT_BUSINESS_TO_SOS_CHANNEL_MAP => {
    $BUSINESS__NAP   => $SOS_CHANNEL__NAP,
    $BUSINESS__OUTNET=> $SOS_CHANNEL__TON,
    $BUSINESS__MRP   => $SOS_CHANNEL__MRP,
    $BUSINESS__JC    => $SOS_CHANNEL__JC,
};

sub _get_shippable_channel_code {
    my ($self) = @_;

    my $channel = $self->get_shippable_channel;

    NAP::XT::Exception::SOS::UnmappableChannel->throw({
        channel => $channel,
    }) unless defined($XT_BUSINESS_TO_SOS_CHANNEL_MAP{$channel->business_id()});

    return $XT_BUSINESS_TO_SOS_CHANNEL_MAP{$channel->business_id()};
}

=head2 use_sos_for_sla_data

Returns true if this object is compatible with the current SOS configuration, and
therefore can make use of the get_sla_data() method. False if not.

=cut
sub use_sos_for_sla_data {
    my ($self) = @_;
    return $self->is_sos_enabled();
}

=head2 get_emergency_sla_data

Can be used to generate the same return values as get_sla_data(). This is only intended
 to be used if there is a problem calling get_sla_data(), such as if SOS is unavailable.

=cut
sub get_emergency_sla_data {
    my ($self) = @_;

    my $now = $self->_get_now();

    return (
        $now->clone->add({ minutes => $self->emergency_sla_interval_in_minutes() }),
        $self->emergency_sla_initial_pick_priority(),
        $now->clone(),
        undef,
        undef
    );
}

sub _get_now {
    my ($self) = @_;
    return $self->schema->db_now();
}
