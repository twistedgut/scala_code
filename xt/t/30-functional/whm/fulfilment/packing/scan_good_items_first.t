#!/usr/bin/env perl

=head1 NAME

scan_good_items_first.t - Scan two items at packing, cancelling one

=head1 DESCRIPTION

Run more than once, in a different order each time:

    * Order with two of the same item
    * Cancel one of them (different one each time)
    * Scan the other one in
    * Check the non-faulty one was scanned in

#TAGS fulfilment packing packingexception iws whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::RunCondition
    export => qw( $iws_rollout_phase );


use Test::More;
use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use Test::Differences;

use Test::XTracker::Artifacts::RAVNI;
use Test::XT::Data::Container;

# Start-up gubbins here. Test plan follows later in the code...
test_prefix("Setup: Framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
    ],
);
my $schema = $framework->schema;
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
    ]},
    dept => 'Customer Care'
});

for my $i (0..1) {

    # create and pick the order
    test_prefix("Setup: Order Shipment on run " . ($i + 1) );
    my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 1 });
    my $order_data = $framework->flow_db__fulfilment__create_order_picked(
        channel  => $channel, products => [@$pids,@$pids], );
    note "shipment $order_data->{'shipment_id'} created";
    my $shipment_id = $order_data->{'shipment_id'};
    my @p = $order_data->{shipment_object}->shipment_items->all;

    # We're doing this so it picks the first and the second one on successive
    # runs, so we can make sure the scanning item doesn't come down to that
    my $fail = $p[$i];
    my $good = $p[!$i+0]; # 1 if $i was 0, 0 if $i was 1

    my ($tote) = Test::XT::Data::Container->get_unique_ids({ how_many => 1 });

    # Go to pack it
    test_prefix("Setup: Shipment to PE on run " . ($i + 1) );

    $framework->mech__fulfilment__set_packing_station( $channel->id );
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $order_data->{tote_id} )
        ->catch_error(
            qr/Please scan item\(s\) from shipment/,
            'Send to PE',
            flow_mech__fulfilment__packing_checkshipment_submit => (
                fail => {
                    $fail->id => "OH NOES IT IS THE MISSING"
                }
            )
        );

    $framework
        ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $p[0]->get_sku )
        ->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $tote );

    # Check that it's the good item in the new tote
    my $good_si = $framework->schema->resultset('Public::ShipmentItem')->find( $good->id );
    is( $good_si->container_id, $tote, "Good item was the one picked" );

}

done_testing();
