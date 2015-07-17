#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::RunCondition
    export => [ qw ( $prl_rollout_phase ) ];

use XTracker::Constants::FromDB   qw(
                                        :channel
                                        :shipment_status
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                        :authorisation_level
                                        :renumeration_type
                                        :renumeration_class
                                        :renumeration_status
                                    );


use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Config::Local         qw( :DEFAULT :carrier_automation );
use XTracker::Database::Shipment    qw( get_postcode_shipping_charges get_state_shipping_charges get_country_shipping_charges
                                        :carrier_automation );
use Test::XTracker::PrintDocs;
use Data::Dump  qw( pp );

my $mech    = Test::XTracker::Mechanize->new;
my $schema  = Test::XTracker::Data->get_schema;
my $channel = Test::XTracker::Data->channel_for_nap;

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::PRL',
    ],
    mech => $mech,
);

Test::XTracker::Data->set_department('it.god', 'Shipping');

__PACKAGE__->setup_user_perms;

$mech->do_login;

note "Creating Order for Channel: ".$channel->name." (".$channel->id.")";

# now DHL is DC2's default carrier for international deliveries need to explicitly set
# the carrier to 'UPS' for this DC2CA test
my $default_carrier = ( $channel->is_on_dc( 'DC2' ) ? 'UPS' : config_var('DistributionCentre','default_carrier') );

my $ship_account    = Test::XTracker::Data->find_shipping_account( { channel_id => $channel->id, carrier => $default_carrier."%" } );

my $pids        = Test::XTracker::Data->find_or_create_products( { channel_id => $channel->id, how_many => 2 } );
my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );
Test::XTracker::Data->ensure_stock( $pids->[1]{pid}, $pids->[1]{size_id}, $channel->id );

my $order_args  = {
        customer_id => $customer->id,
        channel_id  => $channel->id,
        items => {
            $pids->[0]{sku} => { price => 100.00 },
            $pids->[1]{sku} => { price => 150.00 },
        },
        shipment_type => $SHIPMENT_TYPE__DOMESTIC,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id => $ship_account->id,
        invoice_address_id => Test::XTracker::Data->create_order_address_in('current_dc_premier')->id,
        shipping_charge_id => 4,
    };

my $order   = Test::XTracker::Data->create_db_order( $order_args );

my $order_nr = $order->order_nr;

if ( $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE} ) {
    diag "Shipping Acc.: ".$ship_account->id;
    diag "Order Nr: $order_nr";
    diag "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;
}

$mech->order_nr($order_nr);

my $shipment = $order->shipments->first;
Test::XTracker::Data->toggle_shipment_validity( $shipment, 1 );

my ($ship_nr, $status, $category) = gather_order_info();
diag "Shipment Nr: $ship_nr" if $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE};

# The order status might be Credit Hold. Check and fix if needed
if ($status eq "Credit Hold") {
    Test::XTracker::Data->set_department('it.god', 'Finance');
    $mech->reload;
    $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
    ($ship_nr, $status, $category) = gather_order_info();
}
is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

# Get shipment to packing stage
my $skus= $mech->get_order_skus();
my $print_directory = Test::XTracker::PrintDocs->new();

if ($prl_rollout_phase) {
    Test::XTracker::Data::Order->allocate_order($order);
    Test::XTracker::Data::Order->select_order($order);
    my $container_id = Test::XT::Data::Container->get_unique_id({ how_many => 1 });
    $framework->flow_msg__prl__pick_shipment(
        shipment_id => $order->shipments->first->id,
        container => {
            $container_id => [keys %$skus],
        }
    );
    $framework->flow_msg__prl__induct_shipment(
        shipment_row => $order->shipments->first,
    );
} else {
    $mech->test_direct_select_shipment( $ship_nr );
    $skus   = $mech->get_info_from_picklist($print_directory, $skus);
    $mech->test_pick_shipment( $ship_nr, $skus );
}

$mech->test_pack_shipment( $ship_nr, $skus );

# Assign AWB's to the shipment
if ( config_var('Fulfilment', 'labelling_subsection') ) {
    $mech->test_labelling( $ship_nr );
}
else {
    $mech->test_assign_airway_bill( $ship_nr );
}
$mech->test_dispatch( $ship_nr );

test_lost_shipment( $mech, $ship_nr, 1 );

# TODO We expect some files from the above tests: these tests should check them
my @unexpected_files =
    grep { $_->file_type !~ /^(invoice|matchup_sheet|retpro|shippingform|dgn)$/ }
    $print_directory->new_files();

ok(!@unexpected_files, 'should not have any unexpected print files');

done_testing;


=head2 test_lost_shipment

 $mech  = test_lost_shipment($mech,$shipment_id,$oktodo)

Tests the Lost Shipment functionality.

=cut

sub test_lost_shipment {
    my ($mech,$ship_nr,$oktodo)     = @_;

    my $schema      = Test::XTracker::Data->get_schema;
    my $dbh         = $schema->storage->dbh;

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );
    my @ship_items  = $shipment->shipment_items->all;
    my $tmp;
    my $log;

    SKIP: {
        skip "test_lost_shipment",1         if ( !$oktodo );

        note "TESTING Lost Shipment";

        $mech->get_ok( $mech->order_view_url );
        $mech->follow_link_ok( { text_regex => qr/Lost Shipment/ }, "Lost Shipment" );

        note "FIRST ITEM";
        # submit form to lose the first item
        $mech->submit_form_ok({
            with_fields => {
                'item-'.$ship_items[0]->id => 1,
            },
            button => 'submit',
        }, "Lose Item: ".$ship_items[0]->id );
        $mech->no_feedback_error_ok;
        $mech->has_feedback_success_ok( qr/Shipment updated successfully/ );

        # Check Statuses
        $shipment->discard_changes;
        $ship_items[0]->discard_changes;
        # Item Status
        cmp_ok( $ship_items[0]->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__LOST, "Shipment Item Status is 'Lost'" );
        $tmp    = $ship_items[0]->shipment_item_status_logs->search( {}, { order_by => 'me.id DESC' } )->first;
        cmp_ok( $tmp->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__LOST, "Shipment Item Status Log is 'Lost'" );
        # Shipment Status
        cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DISPATCHED, "Shipment Status UN-changed" );
        # Invoice
        $tmp    = $shipment->renumerations->search( {}, { order_by => 'me.id DESC' } )->first;
        cmp_ok( $tmp->renumeration_type_id, '==', $RENUMERATION_TYPE__STORE_CREDIT, "Invoice: renumeration type Store Credit" );
        cmp_ok( $tmp->renumeration_class_id, '==', $RENUMERATION_CLASS__CANCELLATION, "Invoice: renumeration class Cancellation" );
        cmp_ok( $tmp->renumeration_status_id, '==', $RENUMERATION_STATUS__AWAITING_ACTION, "Invoice: renumeration status Awaiting Action" );
        cmp_ok( $tmp->misc_refund, '==', 0, "Invoice: 'misc_refund' should be ZERO no charge for shipping" );
        cmp_ok( $tmp->grand_total, '==', ( $ship_items[0]->unit_price + $ship_items[0]->tax + $ship_items[0]->duty ),
                                            "Invoice: Total as expected" );
        cmp_ok( $tmp->renumeration_tenders->count, '>', 0, "Invoice: has Renumeration Tenders" );
        $tmp    = $tmp->renumeration_status_logs->search( {}, { order_by => 'me.id DESC' } )->first;
        cmp_ok( $tmp->renumeration_status_id, '==', $RENUMERATION_STATUS__AWAITING_ACTION, "Invoice Status Log is 'Awaiting Action'" );

        note "SECOND AND ALL ITEMS";
        # submit form to lose the first item
        $mech->follow_link_ok( { text_regex => qr/Lost Shipment/ }, "Lost Shipment" );
        $mech->submit_form_ok({
            with_fields => {
                'item-'.$ship_items[1]->id => 1,
            },
            button => 'submit',
        }, "Lose Item: ".$ship_items[1]->id );
        $mech->no_feedback_error_ok;
        $mech->has_feedback_success_ok( qr/Shipment updated successfully/ );

        # Check Statuses
        $shipment->discard_changes;
        $ship_items[1]->discard_changes;
        # Item Status
        cmp_ok( $ship_items[1]->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__LOST, "Shipment Item Status is 'Lost'" );
        $tmp    = $ship_items[1]->shipment_item_status_logs->search( {}, { order_by => 'me.id DESC' } )->first;
        cmp_ok( $tmp->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__LOST, "Shipment Item Status Log is 'Lost'" );
        # Shipment Status
        cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__LOST, "Shipment Status is 'Lost'" );
        $tmp    = $shipment->shipment_status_logs->search( {}, { order_by => 'me.id DESC' } )->first;
        cmp_ok( $tmp->shipment_status_id, '==', $SHIPMENT_STATUS__LOST, "Shipment Status Log is 'Lost'" );
        # Invoice
        $tmp    = $shipment->renumerations->search( {}, { order_by => 'me.id DESC' } )->first;
        cmp_ok( $tmp->renumeration_type_id, '==', $RENUMERATION_TYPE__STORE_CREDIT, "Invoice: renumeration type Store Credit" );
        cmp_ok( $tmp->renumeration_class_id, '==', $RENUMERATION_CLASS__CANCELLATION, "Invoice: renumeration class Cancellation" );
        cmp_ok( $tmp->renumeration_status_id, '==', $RENUMERATION_STATUS__AWAITING_ACTION, "Invoice: renumeration status Awaiting Action" );
        cmp_ok( $tmp->misc_refund, '==', 0, "Invoice: 'misc_refund' should be ZERO no charge for shipping" );
        cmp_ok( $tmp->grand_total, '==', ( $shipment->shipping_charge + $ship_items[1]->unit_price + $ship_items[1]->tax + $ship_items[1]->duty ),
                                            "Invoice: Total as expected" );
        cmp_ok( $tmp->renumeration_tenders->count, '>', 0, "Invoice: has Renumeration Tenders" );
        $tmp    = $tmp->renumeration_status_logs->search( {}, { order_by => 'me.id DESC' } )->first;
        cmp_ok( $tmp->renumeration_status_id, '==', $RENUMERATION_STATUS__AWAITING_ACTION, "Invoice Status Log is 'Awaiting Action'" );

        #
        # now reset data and so we can Lose the whole shipment in one go
        #
        $shipment->discard_changes;
        $tmp    = $shipment->renumerations;
        while ( my $renum = $tmp->next ) {
            $renum->renumeration_tenders->delete;
            $renum->renumeration_items->delete;
            $renum->renumeration_status_logs->delete;
            $renum->delete;
        }
        $shipment->shipment_status_logs->search( {}, { order_by => 'me.id DESC' } )->delete;
        $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED } );
        foreach ( @ship_items ) {
            $_->discard_changes;
            $_->shipment_item_status_logs->search( {}, { order_by => 'me.id DESC' } )->first->delete;
            $_->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } );
        }

        note "LOSING ALL IN ONE GO";
        $mech->get_ok( $mech->order_view_url );
        $mech->follow_link_ok( { text_regex => qr/Lost Shipment/ }, "Lost Shipment" );
        $mech->submit_form_ok({
            with_fields => {
                'item-'.$ship_items[0]->id => 1,
                'item-'.$ship_items[1]->id => 1,
            },
            button => 'submit',
        }, "Lose All Items" );
        $mech->no_feedback_error_ok;
        $mech->has_feedback_success_ok( qr/Shipment updated successfully/ );

        # Check Statuses
        $shipment->discard_changes;
        $ship_items[0]->discard_changes;
        $ship_items[1]->discard_changes;
        # Item Status
        cmp_ok( $ship_items[0]->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__LOST, "First Shipment Item Status is 'Lost'" );
        $tmp    = $ship_items[0]->shipment_item_status_logs->search( {}, { order_by => 'me.id DESC' } )->first;
        cmp_ok( $tmp->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__LOST, "First Shipment Item Status Log is 'Lost'" );
        cmp_ok( $ship_items[1]->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__LOST, "Second Shipment Item Status is 'Lost'" );
        $tmp    = $ship_items[1]->shipment_item_status_logs->search( {}, { order_by => 'me.id DESC' } )->first;
        cmp_ok( $tmp->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__LOST, "Second Shipment Item Status Log is 'Lost'" );
        # Shipment Status
        cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__LOST, "Shipment Status is 'Lost'" );
        $tmp    = $shipment->shipment_status_logs->search( {}, { order_by => 'me.id DESC' } )->first;
        cmp_ok( $tmp->shipment_status_id, '==', $SHIPMENT_STATUS__LOST, "Shipment Status Log is 'Lost'" );
        # Invoice
        $tmp    = $shipment->renumerations->search( {}, { order_by => 'me.id DESC' } )->first;
        cmp_ok( $tmp->renumeration_type_id, '==', $RENUMERATION_TYPE__STORE_CREDIT, "Invoice: renumeration type Store Credit" );
        cmp_ok( $tmp->renumeration_class_id, '==', $RENUMERATION_CLASS__CANCELLATION, "Invoice: renumeration class Cancellation" );
        cmp_ok( $tmp->renumeration_status_id, '==', $RENUMERATION_STATUS__AWAITING_ACTION, "Invoice: renumeration status Awaiting Action" );
        cmp_ok( $tmp->misc_refund, '==', 0, "Invoice: 'misc_refund' should be ZERO no charge for shipping" );
        cmp_ok( $tmp->grand_total, '==', ( $shipment->shipping_charge +
                                            $ship_items[0]->unit_price + $ship_items[0]->tax + $ship_items[0]->duty +
                                            $ship_items[1]->unit_price + $ship_items[1]->tax + $ship_items[1]->duty
                                          ),
                                            "Invoice: Total as expected" );
        cmp_ok( $tmp->renumeration_tenders->count, '>', 0, "Invoice: has Renumeration Tenders" );
        $tmp    = $tmp->renumeration_status_logs->search( {}, { order_by => 'me.id DESC' } )->first;
        cmp_ok( $tmp->renumeration_status_id, '==', $RENUMERATION_STATUS__AWAITING_ACTION, "Invoice Status Log is 'Awaiting Action'" );
    }

    return $mech;
}


#------------------------------------------------------------------------------------------------

sub setup_user_perms {
  Test::XTracker::Data->grant_permissions( 'it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR );
  # Perms needed for the order process
  for (qw/Airwaybill Dispatch Packing Picking Selection Labelling/ ) {
    Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', $_, $AUTHORISATION_LEVEL__OPERATOR );
  }
  Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Invalid Shipments', $AUTHORISATION_LEVEL__OPERATOR );
}

# First time check that we can get the order via search
# Other times go straight to that url
sub gather_order_info {
  my ($order_nr) = @_;

  $mech->get_ok($mech->order_view_url);

  # On the order view page we need to find the shipment ID

  my $ship_nr = $mech->get_table_value('Shipment Number:');

  my $status = $mech->get_table_value('Order Status:');


  my $category = $mech->get_table_value('Customer Category:');
  return ($ship_nr, $status, $category);
}
