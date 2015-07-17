package SOS::Shipment;
use NAP::policy "tt", 'class';

=head1 NAME

SOS::Shipment

=head1 DESCRIPTION

An object that represents a single shipment for which an SLA request has been made

=cut

with 'XTracker::Role::WithSchema';
use SOS::Exception::NoNDSelectionTime;
use XTracker::Constants::FromDB qw( :sos_shipment_class_attribute );

has 'shipment_class' => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::SOS::ShipmentClass',
    required    => 1,
    handles     => ['use_truck_departure_times_for_sla']
);

has 'carrier' => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::SOS::Carrier',
    required    => 1,
);

has 'channel' => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::SOS::Channel',
    required    => 1,
);

has [ qw/
        is_express
        is_eip
        is_full_sale
        is_mixed_sale
        is_slow
    / ] => (
    is          => 'ro',
    isa         => 'Bool',
    default     => 0,
);

# This is overridable to make testing easier
has 'processing_time_rs' => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->schema->resultset('SOS::ProcessingTime');
    },
);

has 'processing_times' => (
    is          => 'ro',
    isa         => 'XTracker::Schema::ResultSet::SOS::ProcessingTime',
    lazy        => 1,
    default     => sub {
        my ($self) = @_;
        return $self->processing_time_rs->filter_by_properties({
            shipment_class              => $self->shipment_class(),
            channel                     => $self->channel(),
            ($self->country() ? ( country => $self->country() ) : () ),
            ($self->region() ? ( region => $self->region() ) : () ),
            shipment_class_attributes   => $self->get_shipment_class_attributes(),
        });
    },
    handles => {'processing_time_interval' => 'processing_time_duration' },
);

sub get_shipment_class_attributes {
    my ($self) = @_;

    my %shipment_class_attributes = (
        is_express      => $SOS_SHIPMENT_CLASS_ATTRIBUTE__EXPRESS,
        is_eip          => $SOS_SHIPMENT_CLASS_ATTRIBUTE__EIP,
        is_full_sale    => $SOS_SHIPMENT_CLASS_ATTRIBUTE__FULL_SALE,
        is_mixed_sale   => $SOS_SHIPMENT_CLASS_ATTRIBUTE__MIXED_SALE,
        is_slow         => $SOS_SHIPMENT_CLASS_ATTRIBUTE__SLOW,
    );

    return [
        $self->schema
             ->resultset('SOS::ShipmentClassAttribute')
             ->search({
                 id => [
                     map  { $shipment_class_attributes{$_} }
                     grep { $self->$_ }
                     keys %shipment_class_attributes
                 ]
             })->all
    ];
}

has 'selection_datetime' => (
    is          => 'ro',
    isa         => 'DateTime',
    required    => 1,
);

# This is overridable to make testing easier
has 'truck_departure_rs' => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->schema->resultset('SOS::TruckDeparture');
    },
);

has 'truck_departure_datetime' => (
    is      => 'ro',
    isa     => 'DateTime|Undef',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->truck_departure_rs->get_truck_departure_datetime({
            selection_datetime  => $self->selection_datetime(),
            processing_times    => $self->processing_times(),
            carrier             => $self->carrier(),
            shipment_class      => $self->shipment_class(),
        });
    },
);

has 'country' => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::SOS::Country',
    required    => 1,
);

has 'region' => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::SOS::Region',
);

# This is overridable to make testing easier
has 'wms_priority_rs' => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->schema->resultset('SOS::WmsPriority');
    },
);

has 'wms_priority' => (
    is      => 'ro',
    isa     => 'XTracker::Schema::Result::SOS::WmsPriority',
    lazy    => 1,
    default => sub {
        my ($self) = @_;

        my $shipment_class_attributes = $self->get_shipment_class_attributes();

        return $self->wms_priority_rs->find_wms_priority({
            shipment_class  => $self->shipment_class(),
            country         => $self->country(),
            ($self->region() ? (region => $self->region()) : () ),
            (@$shipment_class_attributes
                ? ( attribute_list => $shipment_class_attributes, )
                : ()
            )
        });
    },
    handles => {
        wms_initial_pick_priority   => 'wms_priority',
        wms_bumped_priority         => 'wms_bumped_priority',
        wms_bumped_interval         => 'bumped_interval',
    },
);

has 'wms_deadline' => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->selection_datetime->clone->add_duration(
            $self->processing_time_interval()
        );
    },
);

has 'wms_bump_deadline' => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my ($self) = @_;

        # Not all shipments can be bumped. If no bump priority or bump interval is set we
        # can assume there is no 'bump' deadline
        my $bump_interval = $self->wms_bumped_interval();
        return undef
            unless defined($bump_interval) && defined($self->wms_bumped_priority());

        return $self->get_sla_datetime->clone->subtract_duration($bump_interval);
    },
);

=head1 Public Methods

=head2 get_sla_datetime

 Returns a DateTime object that represents the SLA for the shipment data given.

=cut
sub get_sla_datetime {
    my ($self) = @_;

    my $sla_datetime;
    if ($self->use_truck_departure_times_for_sla()) {
        $sla_datetime = $self->truck_departure_datetime();
        SOS::Exception::NoTruckDepartureFound->throw() unless $sla_datetime;
    } else {
        $sla_datetime = $self->selection_datetime->clone->add_duration(
            $self->processing_time_interval()
        );
    }

    return $sla_datetime;
}
