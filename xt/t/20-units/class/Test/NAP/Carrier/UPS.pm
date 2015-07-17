package Test::NAP::Carrier::UPS;
use NAP::policy "tt", qw/class test/;

use Test::XTracker::LoadTestConfig;

BEGIN {

extends "NAP::Test::Class";

with 'XTracker::Role::AccessConfig';

};

use Test::MockModule;
use Test::XT::Data;
use NAP::Carrier;
use XTracker::Constants '$APPLICATION_OPERATOR_ID';

sub startup : Test(startup) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{order_factory} = Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::Order' ]
    );
}

sub test_is_autoable :Tests { SKIP: {
    my $self = shift;

    skip "only runs on DC2" unless $self->get_config_var('DistributionCentre', 'name') eq 'DC2';

    my $shipment = $self->{order_factory}->new_order->{shipment_object};

    for (
        [ 'happy path pass',                         'UPS',         0, 0, 0, 'United States', 'NY', 1 ],
        [ 'not autoable with premier shipment',      'UPS',         1, 0, 0, 'United States', 'NY', 0 ],
        [ 'not autoable with virtual vouchers only', 'UPS',         0, 1, 0, 'United States', 'IO', 0 ],
        [ 'not autoable with non-UPS',               'DHL Express', 0, 0, 0, 'United States', 'NY', 0 ],
        [ 'not autoable to non-US',                  'UPS',         0, 0, 0, 'Canada',        '',   0 ],
        [ 'autoable no hazmat to AK',                'UPS',         0, 0, 0, 'United States', 'AK', 1 ],
        [ 'autoable no hazmat to HI',                'UPS',         0, 0, 0, 'United States', 'HI', 1 ],
        [ 'autoable hazmat to US',                   'UPS',         0, 0, 1, 'United States', 'NY', 1 ],
        [ 'not autoable hazmat to AK',               'UPS',         0, 0, 1, 'United States', 'AK', 0 ],
        [ 'not autoable hazmat to HI',               'UPS',         0, 0, 1, 'United States', 'HI', 0 ],
    ) {
        my ( $test_name, $set_carrier, $set_is_premier, $set_is_virtual_voucher_only, $set_hazmat_items, $set_country, $set_county, $expected ) = @$_;

        my $module = Test::MockModule->new('XTracker::Schema::Result::Public::Shipment');
        $module->mock('carrier', sub {
            return $self->schema->resultset('Public::Carrier')->find({name => $set_carrier});
        });
        $module->mock('is_premier', $set_is_premier);
        $module->mock('is_virtual_voucher_only', $set_is_virtual_voucher_only);
        $module->mock('has_hazmat_items', $set_hazmat_items);

        my $address = $shipment->shipment_address;
        $address->update({
            country => $set_country,
            county  => $set_county,
        });

        my $carrier = NAP::Carrier->new({
            schema => $self->schema,
            shipment_id => $shipment->id,
            operator_id => $APPLICATION_OPERATOR_ID,
        });
        is( !!$carrier->is_autoable, !!$expected, $test_name );
    }
}}
