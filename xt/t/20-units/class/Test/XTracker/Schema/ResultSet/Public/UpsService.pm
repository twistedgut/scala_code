package Test::XTracker::Schema::ResultSet::Public::UpsService;
use NAP::policy "tt", qw/test class/;

BEGIN {
use Test::XTracker::LoadTestConfig;
extends 'NAP::Test::Class';

use Test::XTracker::Data::Carrier::UPS;
has 'ups_test_data' => (
    is => 'ro',
    isa => 'Test::XTracker::Data::Carrier::UPS',
    lazy => 1,
    default => sub { return Test::XTracker::Data::Carrier::UPS->new() },
);

};

use XTracker::Constants '$APPLICATION_OPERATOR_ID';
use XTracker::Constants::FromDB qw(
    :shipping_charge_class
    :shipping_class
    :shipping_direction
);
use Test::XTracker::Data::Shipping;
use Test::MockObject;

sub test__filter_for_shipment :Tests {
    my ($self) = @_;

    my ($shipping_charge_defaults_obj, $shipping_charge_specific_obj, $test_service_rs)
        = $self->_create_test_ups_services();

    for my $test (
        {
            name                        => 'Outgoing domestic ground shipment that uses defaults',
            shipping_direction_id       => $SHIPPING_DIRECTION__OUTGOING,
            shipping_class_id           => $SHIPPING_CLASS__DOMESTIC,
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__GROUND,
            shipping_charge_obj         => $shipping_charge_defaults_obj,
            expected_service_codes      => [qw/T1 T2/],
        },
        {
            name                        => 'Return domestic ground shipment that uses defaults',
            shipping_direction_id       => $SHIPPING_DIRECTION__RETURN,
            shipping_class_id           => $SHIPPING_CLASS__DOMESTIC,
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__GROUND,
            shipping_charge_obj         => $shipping_charge_defaults_obj,
            expected_service_codes      => [qw/T4/],
        },
        {
            name                        => 'Outgoing domestic air shipment that uses defaults',
            shipping_direction_id       => $SHIPPING_DIRECTION__OUTGOING,
            shipping_class_id           => $SHIPPING_CLASS__DOMESTIC,
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__AIR,
            shipping_charge_obj         => $shipping_charge_defaults_obj,
            expected_service_codes      => [qw/T3/],
        },
        {
            name                        => 'Return domestic air shipment that uses defaults',
            shipping_direction_id       => $SHIPPING_DIRECTION__RETURN,
            shipping_class_id           => $SHIPPING_CLASS__DOMESTIC,
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__AIR,
            shipping_charge_obj         => $shipping_charge_defaults_obj,
            expected_service_codes      => [qw/T4/],
        },
        {
            name                        => 'Outgoing international ground shipment that uses defaults',
            shipping_direction_id       => $SHIPPING_DIRECTION__OUTGOING,
            shipping_class_id           => $SHIPPING_CLASS__INTERNATIONAL,
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__GROUND,
            shipping_charge_obj         => $shipping_charge_defaults_obj,
            expected_service_codes      => [qw/T2/],
        },
        {
            name                        => 'Return international ground shipment that uses defaults',
            shipping_direction_id       => $SHIPPING_DIRECTION__RETURN,
            shipping_class_id           => $SHIPPING_CLASS__INTERNATIONAL,
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__GROUND,
            shipping_charge_obj         => $shipping_charge_defaults_obj,
            expected_service_codes      => [qw/T4/],
        },
        {
            name                        => 'Outgoing international air shipment that uses defaults',
            shipping_direction_id       => $SHIPPING_DIRECTION__OUTGOING,
            shipping_class_id           => $SHIPPING_CLASS__INTERNATIONAL,
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__AIR,
            shipping_charge_obj         => $shipping_charge_defaults_obj,
            expected_service_codes      => [],
        },
        {
            name                        => 'Return international air shipment that uses defaults',
            shipping_direction_id       => $SHIPPING_DIRECTION__RETURN,
            shipping_class_id           => $SHIPPING_CLASS__INTERNATIONAL,
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__AIR,
            shipping_charge_obj         => $shipping_charge_defaults_obj,
            expected_service_codes      => [],
        },
        {
            name                        => 'Outgoing domestic shipment with specified services (air, but should be ignored)',
            shipping_direction_id       => $SHIPPING_DIRECTION__OUTGOING,
            shipping_class_id           => $SHIPPING_CLASS__DOMESTIC,
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__AIR, # Should be ignored tho
            shipping_charge_obj         => $shipping_charge_specific_obj,
            expected_service_codes      => [qw/T3 T2/],
        },
        {
            name                        => 'Outgoing domestic shipment with specified services (ground, but should be ignored)',
            shipping_direction_id       => $SHIPPING_DIRECTION__OUTGOING,
            shipping_class_id           => $SHIPPING_CLASS__DOMESTIC,
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__GROUND, # Should be ignored tho
            shipping_charge_obj         => $shipping_charge_specific_obj,
            expected_service_codes      => [qw/T3 T2/],
        },
        {
            name                        => 'Return domestic shipment with specified services',
            shipping_direction_id       => $SHIPPING_DIRECTION__RETURN,
            shipping_class_id           => $SHIPPING_CLASS__DOMESTIC,
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__AIR, # Should be ignored tho
            shipping_charge_obj         => $shipping_charge_specific_obj,
            expected_service_codes      => [qw/T1/],
        },
        {
            name                        => 'Outgoing international shipment with specified services',
            shipping_direction_id       => $SHIPPING_DIRECTION__OUTGOING,
            shipping_class_id           => $SHIPPING_CLASS__INTERNATIONAL,
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__AIR, # Should be ignored tho
            shipping_charge_obj         => $shipping_charge_specific_obj,
            expected_service_codes      => [],
        },
        {
            name                        => 'Return international shipment with specified services',
            shipping_direction_id       => $SHIPPING_DIRECTION__RETURN,
            shipping_class_id           => $SHIPPING_CLASS__INTERNATIONAL,
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__AIR, # Should be ignored tho
            shipping_charge_obj         => $shipping_charge_specific_obj,
            expected_service_codes      => [],
        },
    ) {
        subtest $test->{name} => sub {

            note(sprintf('Beginning sub-test: %s', $test->{name}));

            my $mock_shipping_charge_class = Test::MockObject->new();
            $mock_shipping_charge_class->mock('id', sub { $test->{shipping_charge_class_id} });

            my $mock_shipping_class = Test::MockObject->new();
            $mock_shipping_class->mock('id', sub { $test->{shipping_class_id} });

            my $mock_shipment = Test::MockObject->new();
            $mock_shipment->set_isa('XTracker::Schema::Result::Public::Shipment');
            $mock_shipment->mock('get_shipping_charge_class', sub { $mock_shipping_charge_class });
            $mock_shipment->mock('get_shipping_class', sub { $mock_shipping_class });
            $mock_shipment->mock('shipping_charge_table', sub { $test->{shipping_charge_obj} });

            my @services;
            lives_ok {
                @services = $test_service_rs->filter_for_shipment({
                    shipment    => $mock_shipment,
                    is_return   => ($test->{shipping_direction_id} == $SHIPPING_DIRECTION__RETURN
                        ? 1
                        : 0
                    )
                });
            } 'filter_for_shipment() lives';

            my @returned_codes = map { $_->code() } @services;
            is_deeply(\@returned_codes, $test->{expected_service_codes},
                'The correct service codes have been returned');
        };
    }
}

sub _create_test_ups_services {
    my ($self) = @_;

    my $schema = $self->schema();

    my (
        $first_class_service_obj,
        $second_class_service_obj,
        $carrier_pigeon_service_obj,
        $magic_air_service_obj,
        $magic_ground_service_obj
    ) = $self->ups_test_data->create_ups_services([{
            code                        => '1',
            description                 => 'First Class Post',
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__GROUND,
        }, {
            code                        => '2',
            description                 => 'Second Class Post',
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__GROUND,
        }, {
            code                        => '3',
            description                 => 'Carrier Pigeon',
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__AIR,
        }, {
            code                        => '4',
            description                 => 'Magic',
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__AIR,
        }, {
            code                        => '4',
            description                 => 'Magic',
            shipping_charge_class_id    => $SHIPPING_CHARGE_CLASS__GROUND,
        }
    ]);

    my $shipping_charge_defaults_obj = Test::XTracker::Data::Shipping->create_shipping_charge();
    my $shipping_charge_specific_obj = Test::XTracker::Data::Shipping->create_shipping_charge();

    $self->ups_test_data->create_ups_service_availabilities([
        # Available to shipping_charges by default
        {
            ups_service_id      => $first_class_service_obj->id(),
            shipping_class_id   => $SHIPPING_CLASS__DOMESTIC,
            shipping_direction_id => $SHIPPING_DIRECTION__OUTGOING,
            rank                => 1,
        }, {
            ups_service_id      => $second_class_service_obj->id(),
            shipping_class_id   => $SHIPPING_CLASS__DOMESTIC,
            shipping_direction_id => $SHIPPING_DIRECTION__OUTGOING,
            rank                => 1,
        }, {
            ups_service_id      => $carrier_pigeon_service_obj->id(),
            shipping_class_id   => $SHIPPING_CLASS__DOMESTIC,
            shipping_direction_id => $SHIPPING_DIRECTION__OUTGOING,
            rank                => 3,
        }, {
            ups_service_id      => $second_class_service_obj->id(),
            shipping_class_id   => $SHIPPING_CLASS__INTERNATIONAL,
            shipping_direction_id => $SHIPPING_DIRECTION__OUTGOING,
            rank                => 1,
        }, {
            ups_service_id      => $magic_air_service_obj->id(),
            shipping_class_id   => $SHIPPING_CLASS__DOMESTIC,
            shipping_direction_id => $SHIPPING_DIRECTION__RETURN,
            rank                => 1,
        }, {
            ups_service_id      => $magic_ground_service_obj->id(),
            shipping_class_id   => $SHIPPING_CLASS__DOMESTIC,
            shipping_direction_id => $SHIPPING_DIRECTION__RETURN,
            rank                => 1,
        }, {
            ups_service_id      => $magic_ground_service_obj->id(),
            shipping_class_id   => $SHIPPING_CLASS__INTERNATIONAL,
            shipping_direction_id => $SHIPPING_DIRECTION__RETURN,
            rank                => 1,
        },

        # Available to our new shipping_charge
        {
            ups_service_id      => $carrier_pigeon_service_obj->id(),
            shipping_class_id   => $SHIPPING_CLASS__DOMESTIC,
            shipping_direction_id => $SHIPPING_DIRECTION__OUTGOING,
            shipping_charge_id  => $shipping_charge_specific_obj->id(),
            rank                => 1,
        }, {
            ups_service_id      => $second_class_service_obj->id(),
            shipping_class_id   => $SHIPPING_CLASS__DOMESTIC,
            shipping_direction_id => $SHIPPING_DIRECTION__OUTGOING,
            shipping_charge_id  => $shipping_charge_specific_obj->id(),
            rank                => 2,
        }, {
            ups_service_id      => $first_class_service_obj->id(),
            shipping_class_id   => $SHIPPING_CLASS__DOMESTIC,
            shipping_direction_id => $SHIPPING_DIRECTION__RETURN,
            shipping_charge_id  => $shipping_charge_specific_obj->id(),
            rank                => 2,
        },
    ]);

    my $test_service_rs = $schema->resultset('Public::UpsService')->search({
        'me.id' => [
            $first_class_service_obj->id(),
            $second_class_service_obj->id(),
            $carrier_pigeon_service_obj->id(),
            $magic_air_service_obj->id(),
            $magic_ground_service_obj->id()
        ],
    });

    return ($shipping_charge_defaults_obj, $shipping_charge_specific_obj, $test_service_rs);
}
