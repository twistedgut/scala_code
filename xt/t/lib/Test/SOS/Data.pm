package Test::SOS::Data;
use NAP::policy 'tt', 'class';
with 'XTracker::Role::WithSchema';

use MooseX::Params::Validate;
use Test::MockObject::Builder;
use SOS::Shipment;
use DateTime::Duration;

sub create_shipment {
    my ($self, $shipment_class, $carrier, $country, $region, $channel, $selection_datetime,
        $processing_times, $processing_time_rs, $wms_priority) = validated_list(\@_,
        shipment_class          => {
            default => Test::MockObject::Builder->build({
                set_isa => 'XTracker::Schema::Result::SOS::ShipmentClass',
            }),
        },
        carrier                 => {
            default => Test::MockObject::Builder->build({
                set_isa => 'XTracker::Schema::Result::SOS::Carrier',
            }),
        },
        country                 => {
            default => Test::MockObject::Builder->build({
                set_isa => 'XTracker::Schema::Result::SOS::Country',
            }),
        },
        region                  => { optional => 1 },
        channel                 => {
            default => Test::MockObject::Builder->build({
                set_isa => 'XTracker::Schema::Result::SOS::Channel',
            }),
        },
        selection_datetime   => {
            default => Test::MockObject::Builder->build({
                set_isa => 'DateTime',
            }),
        },
        processing_times        => { optional => 1 },
        processing_time_rs      => { optional => 1 },
        wms_priority            => { optional => 1 },
    );

    return SOS::Shipment->new(
        shipment_class          => $shipment_class,
        carrier                 => $carrier,
        country                 => $country,
        channel                 => $channel,
        selection_datetime      => $selection_datetime,
        ($region ? (region => $region) : ()),
        ($processing_times ? (processing_times => $processing_times) : ()),
        ($selection_datetime ? (selection_datetime => $selection_datetime) : ()),
        ($processing_time_rs ? (processing_time_rs => $processing_time_rs) : ()),
        ($wms_priority ? (wms_priority => $wms_priority) : ()),
    );
}

sub find_or_create_country {
    my ($self, $name) = validated_list(\@_,
        name => { isa => 'Str' },
    );

    # Use the name value for all fields for simplicity in testing
    return $self->schema->resultset('SOS::Country')->find_or_create({
        name        => $name,
        api_code    => $name,
    });
}

sub find_or_create_region {
    my ($self, $country, $name) = validated_list(\@_,
        country => { isa => 'XTracker::Schema::Result::SOS::Country' },
        name    => { isa => 'Str' },
    );

    # Use the name value for all fields for simplicity in testing
    return $country->find_or_create_related('regions', {
        name        => $name,
        api_code    => $name,
    });
}

sub find_or_create_carrier {
    my ($self, $name) = validated_list(\@_,
        name => { isa => 'Str' },
    );

    # Use the name value for all fields for simplicity in testing
    return $self->schema->resultset('SOS::Carrier')->find_or_create({
        name        => $name,
        code    => $name,
    });
}

sub find_or_create_shipment_class {
    my ($self, $name) = validated_list(\@_,
        name => { isa => 'Str' },
    );

    # Use the name value for all fields for simplicity in testing
    return $self->schema->resultset('SOS::ShipmentClass')->find_or_create({
        name        => $name,
        api_code    => $name
    });
}

sub find_or_create_channel {
    my ($self, $name) = validated_list(\@_,
        name => { isa => 'Str' },
    );

    # Use the name value for all fields for simplicity in testing
    my $channel = $self->schema->resultset('SOS::Channel')->find({
        name        => $name,
        api_code    => $name,
    });

    $channel //= $self->schema->resultset('SOS::Channel')->create({
        # The id of this column is aligned with XT, so the sequence is not to be relied on
        id          => $self->schema->resultset('SOS::Channel')->get_column('id')->max() + 1,
        name        => $name,
        api_code    => $name,
    });

    return $channel;
}

sub find_or_create_shipment_class_attribute {
    my ($self, $name) = validated_list(\@_,
        name => { isa => 'Str' },
    );

    return $self->schema->resultset('SOS::ShipmentClassAttribute')->find_or_create({
        name => $name,
    });
}

sub find_or_update_processing_time {
    my ($self, $class, $channel, $country, $attribute, $processing_time) = validated_list(\@_,
        class           => { isa => 'Str', optional => 1 },
        channel         => { isa => 'Str', optional => 1 },
        country         => { isa => 'Str', optional => 1 },
        attribute       => { isa => 'Str', optional => 1 },
        processing_time => {},
    );

    return $self->schema->resultset('SOS::ProcessingTime')->update_or_create({
        ($class ? ( class_id => $self->find_or_create_shipment_class(name => $class)->id() ) : () ),
        ($channel ? ( channel_id => $self->find_or_create_channel(name => $channel)->id() ) : () ),
        ($country ? ( country_id => $self->find_or_create_country(name => $country)->id() ) : () ),
        ($attribute ? ( class_attribute_id => $self->find_or_create_shipment_class_attribute(name => $attribute)->id() ) : () ),
        processing_time => $processing_time,
    });
}

sub find_or_update_wms_priority {
    my ($self, $class, $country, $attribute, $wms_priority, $wms_bumped_priority, $bumped_interval) = validated_list(\@_,
        class               => { isa => 'Str', optional => 1 },
        country             => { isa => 'Str', optional => 1 },
        attribute           => { isa => 'Str', optional => 1 },
        wms_priority        => { isa => 'Int' },
        wms_bumped_priority => { isa => 'Int', optional => 1 },
        bumped_interval     => { isa => 'Str', optional => 1 },
    );

    return $self->schema->resultset('SOS::WmsPriority')->update_or_create({
        ($class ? ( shipment_class_id => $self->find_or_create_shipment_class(name => $class)->id() ) : () ),
        ($country ? ( country_id => $self->find_or_create_country(name => $country)->id() ) : () ),
        ($attribute ? ( class_attribute_id => $self->find_or_create_shipment_class_attribute(name => $attribute)->id() ) : () ),
        wms_priority => $wms_priority,
        ( $wms_bumped_priority ? ( wms_bumped_priority => $wms_bumped_priority ) : () ),
        ( $bumped_interval ? ( bumped_interval => $bumped_interval ) : () ),
    });
}

sub find_or_update_override {
    my ($self, $major, $minor) = validated_list(\@_,
        major => { isa => 'HashRef' },
        minor => { isa => 'HashRef' },
    );

    my $major_processing_time = $self->schema->resultset('SOS::ProcessingTime')->find({
        ($major->{class} ? (class_id => $self->find_or_create_shipment_class(name => $major->{class})->id() ) : () ),
        ($major->{channel} ? (channel_id => $self->find_or_create_channel(name => $major->{channel})->id() ) : () ),
        ($major->{country} ? ( country_id => $self->find_or_create_country(name => $major->{country})->id() ) : () ),
        ($major->{attribute} ? ( class_attribute_id => $self->find_or_create_shipment_class_attribute(name => $major->{attribute})->id() ) : () ),
    });

    my $minor_processing_time = $self->schema->resultset('SOS::ProcessingTime')->find({
        ($minor->{class} ? (class_id => $self->find_or_create_shipment_class(name => $minor->{class})->id() ) : () ),
        ($minor->{channel} ? (channel_id => $self->find_or_create_channel(name => $minor->{channel})->id() ) : () ),
        ($minor->{country} ? ( country_id => $self->find_or_create_country(name => $minor->{country})->id() ) : () ),
        ($minor->{attribute} ? ( class_attribute_id => $self->find_or_create_shipment_class_attribute(name => $minor->{attribute})->id() ) : () ),
    });

    return $self->schema->resultset('SOS::ProcessingTimeOverride')->update_or_create({
        major_id => $major_processing_time->id(),
        minor_id => $minor_processing_time->id(),
    });
}

sub create_truck_departure {
    my ($self, $carrier, $departure_time, $shipment_classes, $week_day,
        $begin_date, $end_date, $archived_datetime) = validated_list(\@_,
        carrier             => { isa => 'Str' },
        departure_time      => { isa => 'HashRef' },
        shipment_classes    => { isa => 'ArrayRef[Str]' },
        week_day            => { isa => 'Str' },
        begin_date      => { isa => 'HashRef', optional => 1 },
        end_date        => { isa => 'HashRef', optional => 1 },
        archived_datetime   => { isa => 'HashRef', optional => 1 },
    );

    # If a begin datetime has not been defined, go back to the beginning of time ;)
    $begin_date //= { year => 1970, month => 1, day => 1 };

    my $truck_departure = $self->schema->resultset('SOS::TruckDeparture')->create({
        begin_date  => DateTime->new($begin_date),
        (defined($end_date)
            ? ( end_date => DateTime->new($end_date) )
            :  ()
        ),
        carrier_id      => $self->find_or_create_carrier({ name => $carrier })->id(),
        departure_time  => DateTime::Duration->new($departure_time),
        week_day_id     => $self->schema->resultset('SOS::WeekDay')->find({
            name => $week_day,
        })->id(),
        (defined($archived_datetime)
            ? ( archived_datetime => DateTime->new($archived_datetime) )
            : ()
        ),
    });

    for my $class (@{$shipment_classes}) {
        my $shipment_class = $self->find_or_create_shipment_class({ name => $class});
        $shipment_class->create_related('truck_departure__shipment_classes', {
            truck_departure_id => $truck_departure->id(),
        });
    }
    return $truck_departure;
}

sub create_truck_departure_exception {
    my ($self, $args) = @_;
    my $truck_departure_exception = $self->schema->resultset('SOS::TruckDepartureException')->create({
        exception_date  => DateTime->new($args->{exception_date}),
        carrier_id      => $self->schema->resultset('SOS::Carrier')->find({
            name => $args->{carrier},
        })->id(),
        (defined($args->{departure_time})
            ? (departure_time  => DateTime::Duration->new($args->{departure_time}) )
            : ()
        ),
        (defined($args->{archived_datetime})
            ? ( archived_datetime => DateTime->new($args->{archived_datetime}) )
            :  ()
        ),
    });

    for my $class (@{$args->{shipment_classes}}) {
        my $shipment_class = $self->find_or_create_shipment_class({ name => $class});
        $shipment_class->create_related('truck_departure_exception__shipment_classes', {
            truck_departure_exception_id => $truck_departure_exception->id(),
        });
    }
    return $truck_departure_exception;
}
