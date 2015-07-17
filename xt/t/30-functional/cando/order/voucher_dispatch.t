#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::RunCondition
    export => [qw( $iws_rollout_phase $prl_rollout_phase )];


use Test::NAP::Messaging::Helpers 'atleast','napdate';
use XTracker::Constants           qw( :application );
use XTracker::Constants::FromDB   qw(
                                        :channel
                                        :shipment_status
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                        :authorisation_level
                                    );

use Test::XTracker::Data;
use Test::XTracker::PrintDocs;
use Test::XTracker::MessageQueue;
use Test::XT::Flow;
use XTracker::Config::Local         qw( :DEFAULT :carrier_automation );
use XTracker::Database::Shipment    qw( get_postcode_shipping_charges get_state_shipping_charges get_country_shipping_charges
                                        :carrier_automation );

use Data::Dump  qw( pp );

my $framework = Test::XT::Flow->new_with_traits(
    traits => [ 'Test::XT::Flow::PRL' ],
);
my $mech    = $framework->mech;
my $schema  = Test::XTracker::Data->get_schema;
my @channels= ( Test::XTracker::Data->get_local_channel() );

Test::XTracker::Data->set_department('it.god', 'Shipping');

__PACKAGE__->setup_user_perms;

$mech->do_login;

CHANNEL:
foreach my $channel ( @channels ) {

    note "Creating Order for Channel: ".$channel->name." (".$channel->id.")";

    # now DHL is DC2's default carrier for international deliveries need to explicitly set
    # the carrier to 'UPS' for this DC2CA test
    my $default_carrier = ( $channel->is_on_dc( 'DC2' ) ? 'UPS' : config_var('DistributionCentre','default_carrier') );

    my $ship_account    = Test::XTracker::Data->find_shipping_account( { channel_id => $channel->id, carrier => $default_carrier."%" } );

    my ($tmp,$pids) = Test::XTracker::Data->grab_products( {
                            channel => $channel->business->config_section,
                            how_many => 2,
                            virt_vouchers   => {
                                how_many    => 1,
                            },
                        } );
    $pids->[2]{assign_code_to_ship_item}    = 1;
    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    my $base    = {
            customer_id => $customer->id,
            channel_id  => $channel->id,
            shipment_type => $SHIPMENT_TYPE__DOMESTIC,
            shipment_status => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
            shipping_account_id => $ship_account->id,
            invoice_address_id => Test::XTracker::Data->create_order_address_in('current_dc_premier')->id,
            shipping_charge_id => 4,
        };

    my $order;
    ( $order, $tmp ) = Test::XTracker::Data->create_db_order( {
                        base    => $base,
                        pids    => $pids,
                        attrs   => [
                                { price => 100 },
                                { price => 150 },
                            ],
                    } );

    my $shipment = $order->shipments->first;
    Test::XTracker::Data->toggle_shipment_validity( $shipment, 1 );

    # log NEW status for items
    my @items   = $order->shipments->first->shipment_items->all;
    foreach my $item ( @items ) {
        $item->create_related( 'shipment_item_status_logs', {
                                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                                                operator_id => $APPLICATION_OPERATOR_ID,
                                            } );
        # set the virtual voucher to the correct status
        if ( $item->is_virtual_voucher ) {
            map {
                $item->create_related( 'shipment_item_status_logs', {
                                                shipment_item_status_id => $_,
                                                operator_id => $APPLICATION_OPERATOR_ID,
                                        } ) }
                ( $SHIPMENT_ITEM_STATUS__SELECTED, $SHIPMENT_ITEM_STATUS__PICKED );
            $item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED } );
        }
    }

    my $order_nr = $order->order_nr;

    if ( $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE} ) {
        diag "Shipping Acc.: ".$ship_account->id;
        diag "Order Nr: $order_nr";
        diag "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;
    }

    $mech->order_nr($order_nr);

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
    my $skus    = $mech->get_order_skus();
    my $vskus   = Test::XTracker::Data->stripout_vvoucher_from_skus( $skus );
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
        {
        my $print_directory = Test::XTracker::PrintDocs->new();
        $mech->test_direct_select_shipment( $ship_nr );
        $skus   = $mech->get_info_from_picklist($print_directory,$skus) if $iws_rollout_phase == 0;
        }
        $mech->test_pick_shipment( $ship_nr, $skus );
    }

    $mech->test_pack_shipment( $ship_nr, $skus );

    # Keeping 'DC1' check here instead of IWS, as from what I can tell the
    # labelling at this stage is actually specific to DC1, and has nothing to
    # do with whether you have IWS enabled or not.
    # Assign AWB's to the shipment
    if ( $channel->is_on_dc( 'DC1' ) ) {
        $mech->test_labelling( $ship_nr );
    }
    else {
        my $print_directory = Test::XTracker::PrintDocs->new();
        $mech->test_assign_airway_bill( $ship_nr );
        my ($invoice) = grep { $_->file_type eq 'invoice' }
            $print_directory->new_files();
        $print_directory->non_empty_file_exists_ok( $invoice->filename, 'should find invoice file '.$invoice->full_path );
    }

    test_dispatch($mech,$ship_nr,1);
}

done_testing;


=head2 test_dispatch

 $mech  = test_dispatch($mech,$shipment_id,$oktodo)

This tests the Dispatch process by either using a Shipment Id or a Outward AWB, also tests that the dispatch process works in both normal Full Screen mode and Hand Held mode.

=cut

sub test_dispatch {
    my ($mech,$ship_nr,$oktodo)     = @_;

    my $schema      = Test::XTracker::Data->get_schema;
    my $dbh         = $schema->storage->dbh;

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );
    my $out_awb     = $shipment->outward_airway_bill;

    # set-up AMQ stuff
    my $amq         = Test::XTracker::MessageQueue->new;
    my $order_queue = config_var('Producer::Orders::Update','routes_map')
        ->{$shipment->order->channel->web_name};

    SKIP: {
        skip "test_dispatch",1     if ( !$oktodo );

        note "TESTING Dispatch";

        # Test normal full screen mode

        # check that when Manager level access can see List of Shipments
        Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Dispatch', $AUTHORISATION_LEVEL__MANAGER );
        $mech->get_ok('/Fulfilment/Dispatch');
        $mech->content_like( qr/Shipments Awaiting Dispatch/, "Can find Table of Shipments as Manager" );
        ok $mech->find_xpath( "//td/a[.='$ship_nr']", 'Found Shipment Id in List' );

        # clear the AMQ queue
        $amq->clear_destination( $order_queue );

        $mech->submit_form_ok({
            with_fields => {
                    shipment_id     => $ship_nr,
                },
            button  => 'submit'
        }, "Full Page - Using Shipment Id: ".$ship_nr );
        $mech->no_feedback_error_ok;
        $mech->has_feedback_success_ok(qr/The shipment was successfully dispatched/,"Shipment Dispatched by Id");

        $shipment->discard_changes;
        cmp_ok( $shipment->shipment_status_id, "==", $SHIPMENT_STATUS__DISPATCHED, "Shipment Status is set to Dispatched" );

        my @amq_items;
        my @items   = $shipment->shipment_items->search( {}, { order_by => 'me.id ASC' } )->all;
        foreach my $item ( @items ) {
            cmp_ok( $item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED,
                                        "Shipment Item Status is Dispatched" );
            if ( $item->is_virtual_voucher ) {
                push @amq_items, superhashof({
                        sku         => $item->get_true_variant->sku,
                        xtLineItemId=> $item->id,
                        status      => 'Dispatched',
                        voucherCode => $item->voucher_code->code,
                        returnable  => 'N',
                    });

            }
            else {
                push @amq_items, superhashof({
                        sku         => $item->get_true_variant->sku,
                        xtLineItemId=> $item->id,
                        status      => 'Dispatched',
                        returnable  => 'Y',
                    });
            }
        }

        # check the AMQ message to the web site was sent
        $amq->assert_messages( {
            destination => $order_queue,
            filter_header => superhashof({
                type => 'OrderMessage',
                JMSXGroupID => $shipment->order->channel->lc_web_name,
            }),
            filter_body => superhashof({
                orderNumber => $shipment->order->order_nr,
                status      => 'Dispatched',
                orderItems  => bag(@amq_items),
            }),
            assert_count => atleast(1),
        }, "AMQ Dispatch Message to Web-Site OK" );
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
