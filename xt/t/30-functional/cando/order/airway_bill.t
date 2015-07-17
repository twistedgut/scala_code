#!/usr/bin/env perl
use NAP::policy qw/test/;
use FindBin::libs;

# The airwaybill functionality we're testing here is used only for DHL, so
# we've deliberately excluded DC2 from this test because they use UPS for
# domestic orders and don't follow the same process.
# This test should be enabled in DC3 though - see WHM-2025.
use Test::XTracker::RunCondition dc => 'DC1', export => [qw( $iws_rollout_phase )];

use Data::Dumper;
use Log::Log4perl ':easy';

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::XTracker::PrintDocs;

use XTracker::Constants::FromDB   qw(
    :channel
    :shipment_item_status
    :shipment_status
    :shipment_class
    :shipment_type
);
use Carp::Always;

my $SCHEMA = Test::XTracker::Data->get_schema;

my $CHANNEL_ID  = $SCHEMA->resultset('Public::Channel')->search({
    'name' => 'theOutnet.com',
})->first->id;
my $CUSTOMER    = Test::XTracker::Data->find_customer( { channel_id => $CHANNEL_ID } );

my $ADDRESS = Test::XTracker::Data->create_order_address_in('current_dc');

# Set the user permissions for "the order process":
Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);

Test::XTracker::Data->grant_permissions('it.god', 'Fulfilment', $_, 2) # 2 == ??
    foreach qw( Airwaybill Dispatch Packing Picking Selection Labelling);

my $MECH = Test::XTracker::Mechanize->new;

$MECH->do_login or die("Could not log in, no point continuing");

TRACE "Init OK";

# Run tests on two types of shipping account
foreach my $shipping_ac_id (
    6,  # 'DHL Express (International Road)'
    1,  # 'DHL Express (Domestic)'
) {
    TRACE "Test shipping account ", $shipping_ac_id;

    TRACE "Getting pids of products to use in test";
    my ($channel,$pids) = Test::XTracker::Data->grab_products({
            how_many => 2,
            channel  => 'outnet',
            ensure_stock_all_variants => 1,
    });

    is( $#$pids, 1, "number of pids");

    # Should $CHANNEL and $channel somehow equate?
    undef $channel; # Not used



    my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
        base => {
            customer_id          => $CUSTOMER->id,
            invoice_address_id   => $ADDRESS->id,
            channel_id           => $CHANNEL_ID,
            shipment_status      => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__PICKED,
            shipment_type        => $SHIPMENT_TYPE__INTERNATIONAL,
            shipping_account_id  => $shipping_ac_id,
        },
        pids  => $pids,
        attrs => [
            { price => 100.00 },
            { price => 250.00 },
        ],
    });

    my $order_nr = $order->order_nr;
    $MECH->order_nr($order_nr);

    if ( $ENV{HARNESS_VERBOSE} or $ENV{HARNESS_IS_VERBOSE} ) {
        diag "Shipping Acc.: $shipping_ac_id";
        diag "Order Nr: $order_nr";
        diag "Cust Nr/Id : ".$CUSTOMER->is_customer_number."/".$CUSTOMER->id;
    }

    my ($ship_num, $status, $category) = gather_order_info();
    note "Shipment Nr: $ship_num";

    # TODO will never happen with fixtures
    # The order status might be Credit Hold. Check and fix if needed
    if ($status eq "Credit Hold") {
        Test::XTracker::Data->set_department('it.god', 'Finance');
        $MECH->reload;
        $MECH->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
        ($ship_num, $status, $category) = gather_order_info();
    }

    is( $status,
        $MECH->get_table_value('Order Status:'),
        "Order accepted, status ".$status
    );

    my $skus = $MECH->get_order_skus();

    # We want to make the shipment pickable so we can pick it in to a tote.
    {
        note "Making shipment selectable";
        my $shipment_items =
            $SCHEMA->resultset('Public::Shipment')->find( $ship_num )->shipment_items;
        while (my $item = $shipment_items->next){
            $item->update({shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW});
        }
        $shipment_items->reset; #reset the index
    }

    {
    my $print_directory = Test::XTracker::PrintDocs->new();
    $MECH->test_direct_select_shipment( $ship_num );
    $skus   = $MECH->get_info_from_picklist($print_directory,$skus) if $iws_rollout_phase == 0;
    }
    $MECH
        ->test_pick_shipment($ship_num, $skus)
        ->test_pack_shipment($ship_num, $skus)
        ->test_labelling($ship_num);

    test_cant_dispatch_without_return_awb( $ship_num )
         ->test_dispatch( $ship_num );

}

done_testing;


=head2 SUB test_cant_dispatch_without_return_awb

    test_cant_dispatch_without_return_awb( $shipment_id )

Tests that the Fulfilment -E<gt> Dispatch will not dispatch without
a Return Airway Bill. Premier and UPS orders should not use this
test. (XXX Why not? What should they do?)

=cut

sub test_cant_dispatch_without_return_awb {
    my ($ship_num) = shift;

    my $shipment    = Test::XTracker::Data->get_schema->resultset('Public::Shipment')->find( $ship_num );
    my $ret_awb     = $shipment->return_airway_bill;        # store Return AWB to re-assign later

    # clear return AWB for test
    $shipment->update( { 'return_airway_bill' => 'none' } );

    $MECH->get_ok('/Fulfilment/Dispatch');

    $MECH->submit_form_ok({
      with_fields => {
        shipment_id => $ship_num,
      },
      button => 'submit'
    }, "Dispatch shipment without Return AWB");

    $MECH->has_feedback_error_ok(qr/The shipment does not have AWBs assigned/);

    $shipment->update( { 'return_airway_bill' => $ret_awb } );

    return $MECH;
}




=head2 SUB gather_order_info

First time check that we can get the order via search
Other times go straight to that url

=cut

sub gather_order_info {

    my ($order_nr) = @_;

    $MECH->get_ok( $MECH->order_view_url );

    # On the order view page we need to find the shipment ID

    my $ship_num = $MECH->get_table_value('Shipment Number:');

    my $status = $MECH->get_table_value('Order Status:');

    my $category = $MECH->get_table_value('Customer Category:');
    return ($ship_num, $status, $category);
}
