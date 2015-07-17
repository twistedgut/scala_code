#!/usr/bin/env perl

=head1 NAME

shipment_cancel_after_pick.t - Verify messages if a shipment is cancelled after picking

=head1 DESCRIPTION

Test to ensure we send the correct messages if a shipment is cancelled after
picking, but before packing.

Also test cancelling a shipment before shipment_ready.

For each of the following scenarios:
    a) single non-packable shipment in a tote
    b) multiple shipments in a tote, some packable, some not.
    c) multiple non-packable shipments in a tote

...do the following:
    * create shipment(s), selected
    * receive shipment_ready
    * cancel shipment(s)
    * ensure we send shipment_cancel
    * scan tote to start packing
    * ensure we send shipment_received

#TAGS fulfilment picking cancel loops iws whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::More::Prefix qw/test_prefix/;
use Test::Differences;
use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB qw(:authorisation_level);
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;

use Test::XTracker::RunCondition iws_phase => 'iws';

# Start-up gubbins here. Test plan follows later in the code...
test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Data::Location',
        'Test::XT::Flow::WMS',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Selection'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);

my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

my $test_cases = [
    {shipments => 1,
     cancelled => 1,},
    {shipments => 2,
     cancelled => 1,},
    {shipments => 2,
     cancelled => 2,},
];

foreach my $test_case (@$test_cases){
    test_prefix("Test case definition - ");
    note "Shipments in tote : $test_case->{shipments}, cancelled shipments : $test_case->{cancelled}";

    my ($container_id) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );
    my $orders = place_orders($test_case->{shipments});
    pick_order($_, $container_id) for @$orders;
    cancel_shipments($orders, $test_case->{cancelled});
    tote_at_packer($orders, $container_id);
}

# Also test cancelling a shipment before shipment_ready
{
    test_prefix("Test case definition - ");
    note "Shipments in tote : 1, cancelled shipments : 1, but cancelled before shipment_ready";
    my ($container_id) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );
    my $orders = place_orders(1);

    # as it's not picked yet, we shouldn't be able to pack it and scanning the
    # shipment at packing should complain and send no messages!
    $framework->flow_mech__fulfilment__packing;
    $framework->errors_are_fatal(0);
    $framework->flow_mech__fulfilment__packing_submit( $orders->[0]->{shipment_id} );
    like ($framework->mech->app_error_message,
          qr{This shipment should not be at packing, as the shipment items are not in containers},
          "Don't allow scanning shipments for which we've not received a shipment_ready message");
    $framework->errors_are_fatal(1);

    cancel_shipments($orders, 1);
    my $shipment_item = $orders->[0]->{shipment_object}->shipment_items->first;
    ok($shipment_item->is_cancelled, "shipment_item is cancelled initially");
    pick_order($_, $container_id) for @$orders;
    $shipment_item->discard_changes;
    ok($shipment_item->is_cancel_pending, "shipment_item is cancel_pending once we have received shipment_ready");
    tote_at_packer($orders, $container_id);
}


done_testing();


sub place_orders {
    my ($how_many) = @_;
    # create order
    test_prefix("Setup: place $how_many order(s)");
    my @order_details;
    foreach (1..$how_many){
        my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 1 });

        my $order_data = $framework->flow_db__fulfilment__create_order_selected( channel  => $channel, products => [ $pids->[0] ], );
        push @order_details, $order_data;
        note "shipment $order_data->{'shipment_id'} created";
    }

    return \@order_details;
}

sub pick_order {
    my ($order, $container_id) = @_;

    # Make sure we only send the picking commenced message once per shipment
    $framework->flow_wms__send_picking_commenced( $order->{shipment_object} )
        unless $order->{picking_commenced_sent}++;
    $framework->flow_wms__send_shipment_ready(
        shipment_id => $order->{shipment_id},
        container => {
            $container_id => [ $order->{product_objects}->[0]->{sku} ],
        },
    );
}

sub cancel_shipments {
    my ($orders, $how_many) = @_;
    for my $which (1..$how_many){
        my $theorder = $orders->[$which - 1];
        test_prefix("Cancelling Shipment $which");
        $framework
            ->flow_mech__customercare__cancel_order( $theorder->{'order_object'}->id )
            ->flow_mech__customercare__cancel_order_submit
            ->flow_mech__customercare__cancel_order_email_submit;

        is( $framework->mech->as_data->{'meta_data'}->{'Order Details'}->{'Order Status'},
            'Cancelled', 'Order has been cancelled');
        $xt_to_wms->expect_messages({
            messages => [
                {
                    '@type'   => 'shipment_cancel',
                    'details' => { 'shipment_id' => "s-$theorder->{shipment_id}", },
                },
            ]
        });

    }
}


sub tote_at_packer {
    my ($orders, $container_id) = @_;
    test_prefix("Tote $container_id at packer");

    $framework->flow_mech__fulfilment__packing;
    $framework->flow_mech__fulfilment__packing_submit( $container_id );

    $xt_to_wms->expect_messages({
        messages => [
            map
            {
                '@type'   => 'shipment_received',
                'details' => { 'shipment_id' => "s-$_->{shipment_id}", },
            }, @$orders
        ]
    });
}
