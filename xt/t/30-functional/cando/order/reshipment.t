#!/usr/bin/env perl
# Test reshipments for standard orders, nothing clever, just test that
# the reshipment is successfully created and can be packed and dispatched.
#
# TODO: test replacements too, and test with extra_charges = 1
#
# This test would've caught REL-2421
# "XT DC2 > Fulfilment > Selection > Orders on hold due to invalid addresses"
# if it had existed at the time.
#
use NAP::policy "tt", 'test';

use FindBin::libs;


use XTracker::Constants::FromDB   qw(
                                        :business
                                        :channel
                                        :shipment_status
                                        :shipment_item_returnable_state
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                        :authorisation_level
                                    );

use Test::XTracker::Data;

use Test::XTracker::Artifacts::RAVNI;


use Test::XTracker::Mechanize;
use XTracker::Config::Local         qw( :DEFAULT :carrier_automation );
use XTracker::Database::Shipment    qw( get_postcode_shipping_charges get_state_shipping_charges get_country_shipping_charges
                                        :carrier_automation );

use Test::XTracker::PrintDocs;
use Data::Dump  qw( pp );

my $mech    = Test::XTracker::Mechanize->new;
$mech->force_datalite(1);

my $flow = Test::XT::Flow->new_with_traits(
    traits => ['Test::XT::Flow::CustomerCare','Test::XT::Flow::Fulfilment'],
    mech   => $mech,
);


my $schema  = Test::XTracker::Data->get_schema;
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');


my @channels= $schema->resultset('Public::Channel')->search({'is_enabled'=>1},{ order_by => 'id' })->all;

Test::XTracker::Data->set_department('it.god', 'Distribution Management');
__PACKAGE__->setup_user_perms;
$mech->do_login;

CHANNEL:
foreach my $channel ( @channels ) {

    note "Creating Order for Channel: ".$channel->name." (".$channel->id.")";

    # now DHL is DC2's default carrier for international deliveries need to explicitly set
    # the carrier to 'UPS' for this DC2CA test
    my $default_carrier = ( $channel->is_on_dc( 'DC2' ) ? 'UPS' : config_var('DistributionCentre','default_carrier') );

    my $ship_account    = Test::XTracker::Data->find_shipping_account( { channel_id => $channel->id, carrier => $default_carrier."%" } );

    my $pids        = Test::XTracker::Data->find_or_create_products( { channel_id => $channel->id, how_many => 2 } );
    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    my $order_args  = {
            customer_id => $customer->id,
            channel_id  => $channel->id,
            items => {
                $pids->[0]{sku} => { price => 100.00 },
            },
            shipment_type => $SHIPMENT_TYPE__DOMESTIC,
            shipment_status => $SHIPMENT_STATUS__DISPATCHED,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__DISPATCHED,
            shipping_account_id => $ship_account->id,
            invoice_address_id => Test::XTracker::Data->create_order_address_in('current_dc_premier')->id,
            shipping_charge_id => 4,
            dhl_destination => 'LHR',
            av_quality_rating => '1.0',
        };

    # create order
    my $order   = Test::XTracker::Data->create_db_order( $order_args );

    my $order_nr = $order->order_nr;

    $flow->mech->order_nr($order_nr);

    my ($ship_nr, $status, $category) = gather_order_info();
    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );

    # update all Items to be 'CC Only' Return to make sure the state get copied to the new Items
    $shipment->shipment_items->update( { returnable_state_id => $SHIPMENT_ITEM_RETURNABLE_STATE__CC_ONLY } );

    if ( $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE} ) {
        diag "Shipping Acc.: ".$ship_account->id;
        diag "Order Nr: $order_nr";
        diag "Shipment Nr: $ship_nr";
        diag "Shipping Type: ".$shipment->shipment_type->type;
        diag "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;
    }

    $flow->flow_mech__customercare__create_shipment;
    #$flow->debug_http(2);
    $flow->flow_mech__customercare__create_shipment_submit();
    my $shipment_item_ids = [map {$_->id} $shipment->shipment_items->all()];
    $flow->flow_mech__customercare__create_shipment_item_submit($shipment_item_ids);
    $flow->flow_mech__customercare__create_shipment_final_submit();
    $flow->assert_location(qr!^/CustomerCare/OrderSearch/OrderView\?order_id=\d+!);
    my $shipment_numbers = $mech->get_table_values('Shipment Number:');
    my @sorted_shipment_numbers = sort {$a <=> $b} @$shipment_numbers;
    my $old_shipment_number = shift @sorted_shipment_numbers;
    is ($old_shipment_number, $ship_nr, "First shipment still appears: $old_shipment_number");
    my $new_shipment_number = shift @sorted_shipment_numbers;
    like ($new_shipment_number, qr/^\d+$/, "New shipment has been created: $new_shipment_number");

    my $new_shipment    = $schema->resultset('Public::Shipment')->find( $new_shipment_number );
    cmp_ok( $new_shipment->shipment_items->first->returnable_state_id, '==', $SHIPMENT_ITEM_RETURNABLE_STATE__CC_ONLY,
                                    "Returnable State Id on New Shipment Items copied from the Original" );

    my $print_directory = Test::XTracker::PrintDocs->new();

    # Now check that the new shipment can be processed successfully

    # Reshipments go straight to packing
    my $skus= $flow->mech->get_order_skus();
    $flow->mech->test_pack_shipment( $new_shipment_number, $skus );

    # TODO: Write tests to check for these specific file types instead of just
    # checking the expected number of generated documents
    # Invoices don't get printed cos this is a re-shipment
    # Assign AWB's to the shipment
    if ( config_var('Fulfilment', 'labelling_subsection') ) {
        $flow->mech->test_labelling( $new_shipment_number );
        my $expected_file_count = $channel->is_fulfilment_only ? 2 : 1;
        $expected_file_count++ if $shipment->has_hazmat_lq_items && !$shipment->is_premier;
        # shippingform
        # dangerous goods note if shipment has hazmat LQ item(s) and is not premier
        # retpro (ONLY for JIMMYCHOO)

        my @print_docs = $print_directory->wait_for_new_files( files => $expected_file_count );
    } else {
        $flow->mech->test_assign_airway_bill( $new_shipment_number );
        # For DC2:
        # * retpro (ONLY for JIMMYCHOO)
        # * shippingform
        # * matchup sheet
        # For DC3
        # * shippingform
        # * retpro (ONLY for JIMMYCHOO)
        my $expected_file_count = $channel->is_on_dc('DC2') ? 1 :
                                  $channel->is_on_dc('DC3') ? 1 :
                                  die 'test only supports DC1-3';
        $expected_file_count++ if $channel->is_fulfilment_only;
        my @print_docs = $print_directory->wait_for_new_files( files => $expected_file_count );
    }

    $flow->flow_mech__fulfilment__dispatch
         ->flow_mech__fulfilment__dispatch_shipment($new_shipment->id);
}

my $new_files = $xt_to_wms->new_files();
is ($new_files, 0, "LIVE-80 has been done");

done_testing;


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
