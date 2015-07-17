#!/usr/bin/env perl
use NAP::policy qw/test/;
use Test::XTracker::RunCondition
    dc => [ qw( DC1 DC2 ) ],
    export => [ qw( $iws_rollout_phase $prl_rollout_phase ) ];

use XTracker::Constants::FromDB   qw(
                                        :channel
                                        :shipment_status
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                        :stock_action
                                        :return_status
                                        :return_type
                                        :return_item_status
                                        :renumeration_class
                                        :renumeration_status
                                        :customer_issue_type
                                    );

use Test::XTracker::Data;

use Test::XT::Flow;
use Test::XTracker::Mechanize;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local         qw( :DEFAULT :carrier_automation dc_address );
use XTracker::Database::Shipment    qw( get_postcode_shipping_charges get_state_shipping_charges get_country_shipping_charges
                                        :carrier_automation );
use XT::Business;

use Test::XTracker::PrintDocs;
use Test::NAP::Messaging::Helpers 'napdate';

my $flow     = Test::XT::Flow->new_with_traits(
    traits => [ 'Test::XT::Flow::Fulfilment', 'Test::XT::Flow::PRL' ],
);
my $mech     = $flow->mech;
my $amq      = Test::XTracker::MessageQueue->new;
my $schema   = Test::XTracker::Data->get_schema;
my @channels = $schema->resultset('Public::Channel')
                      ->search({'is_enabled'=>1},{ order_by => 'id' })
                      ->all;

my $username = 'it.god';
Test::XTracker::Data->set_department($username, 'Shipping');

__PACKAGE__->setup_user_perms;

$mech->do_login;

CHANNEL:
foreach my $channel ( @channels ) {
    $flow->mech__fulfilment__set_packing_station( $channel->id );

    note "Creating Order for Channel: ".$channel->name." (".$channel->id.")";

    # now DHL is DC2's default carrier for international deliveries need to explicitly set
    # the carrier to 'UPS' for this DC2CA test
    my $default_carrier = $channel->is_on_dc( 'DC2' )
                        ? 'UPS'
                        : config_var('DistributionCentre','default_carrier');

    isa_ok( my $ship_account = Test::XTracker::Data->find_or_create_shipping_account({
        channel_id => $channel->id, carrier => $default_carrier."%"
    }), 'XTracker::Schema::Result::Public::ShippingAccount' );
    my $prem_postcode   = Test::XTracker::Data->find_prem_postcode( $channel->id );
    my $postcode = defined $prem_postcode
                 ? $prem_postcode->postcode
                 : ( $channel->is_on_dc( 'DC2' ) ? '11371' : 'NW10 4GR' )
    ;
    my $dc_address = dc_address($channel);
    my $address = Test::XTracker::Data->order_address({
        address         => 'create',
        address_line_1  => $dc_address->{addr1},
        address_line_2  => $dc_address->{addr2},
        address_line_3  => $dc_address->{addr3},
        towncity        => $dc_address->{city},
        county          => '',
        country         => $dc_address->{country},
        postcode        => $postcode,
    });

    my ( $forget, $pids )   = Test::XTracker::Data->grab_products({
        channel => $channel,
        how_many => 2,
        ensure_stock_all_variants => 1,
    });

    my $order_args  = {
        pids    => $pids,
        attrs   => [
            { price => 100.00, tax => 10.00, duty => 5.00 },
            { price => 110.00, tax => 11.00, duty => 6.00 },
        ],
        base    => {
            channel_id => $channel->id,
            shipment_type => $SHIPMENT_TYPE__DOMESTIC,
            shipment_status => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
            shipping_account_id => $ship_account->id,
            invoice_address_id => $address->id,
            shipping_charge_id => 4,
        }
    };

    my ( $order, $order_hash )  = Test::XTracker::Data->create_db_order( $order_args );
    my $shipment = $order->shipments->first;
    my $customer = $order->customer;
    Test::XTracker::Data->toggle_shipment_validity( $shipment, 1 );

    my $order_nr = $order->order_nr;

    if ( $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE} ) {
        note "Shipping Acc.: ".$ship_account->id;
        note "Order Nr: $order_nr";
        note "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;
    }

    $mech->order_nr($order_nr);

    my ($ship_nr, $status, $category) = gather_order_info();
    note "Shipment Nr: $ship_nr" if $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE};

    # The order status might be Credit Hold. Check and fix if needed
    if ($status eq "Credit Hold") {
        Test::XTracker::Data->set_department($username, 'Finance');
        $mech->reload;
        $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
        ($ship_nr, $status, $category) = gather_order_info();
    }
    is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

    # Get shipment to packing stage
    my $skus = $mech->get_order_skus();
    my $print_directory = Test::XTracker::PrintDocs->new();
    if ($prl_rollout_phase) {
        Test::XTracker::Data::Order->allocate_order($order);
        Test::XTracker::Data::Order->select_order($order);
        my $container_id = Test::XT::Data::Container->get_unique_id({ how_many => 1 });
        $flow->flow_msg__prl__pick_shipment(
            shipment_id => $order->shipments->first->id,
            container => {
                $container_id => [keys %$skus],
            }
        );
        $flow->flow_msg__prl__induct_shipment(
            shipment_row => $order->shipments->first,
        );
    } else {
        $mech->test_direct_select_shipment( $ship_nr );
        $skus = $mech->get_info_from_picklist($print_directory, $skus) if $iws_rollout_phase == 0;
        $mech->test_pick_shipment( $ship_nr, $skus );
    }
    $mech->test_pack_shipment( $ship_nr, $skus );

    # If we have a seperate labelling section, only the shipping-input form
    # is printed here. Else we expect to get the returns-proforma and invoice too.
    # Now all DCs print at packing ... so number of expected files should be constant
    my $expected_number_of_docs = 3;

    # Except that when using UPS this test was built around the fact that they expect
    # carrier-automation to fail (!), and therefore we only get the shipping-input form
    # in that case too
    $expected_number_of_docs = 1 if $default_carrier eq 'UPS';

    my %file_name_object = $print_directory->wait_for_new_filename_object(
        files => ( $expected_number_of_docs ),
    );

    # Clear any automation/airwaybill data assigned the shipment, else dispatch/return
    # will fail
    $shipment->discard_changes;
    $shipment->clear_carrier_automation_data;

    Test::XTracker::Data->set_department($username, 'Distribution Management');
    test_dispatch_return($mech,$amq,$channel,$ship_nr);
}

done_testing;


=head2 test_dispatch_return

 $mech  = test_dispatch_return($mech,$amq,$channel,$shipment_id)

This tests the Dispatch/Return process.

=cut

sub test_dispatch_return {
    my ($mech,$amq,$channel,$ship_nr)       = @_;

    my $schema      = Test::XTracker::Data->get_schema;
    my $dbh         = $schema->storage->dbh;

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );

    # update the first shipment item to be dispatched
    #
    # This isn't actually a real-world scenario as you should
    # never be-able to part dispatch an order (unless an item has been cancelled)
    # but it does test the fail-safe written into the 'Dispatch/Return' page
    # that should not set for return dispatch shipment items.
    #
    my $ship_item   = $shipment->shipment_items->first;
    $ship_item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } );
    # save this shipment id to exclude in later tests
    my $disp_sid    = $ship_item->id;
    # get the expected number or items to be returned each time
    # basically number shipment items minus the 1 set to dispatched
    my $expected_num_ret_items  = $shipment->shipment_items->count( { 'me.id' => { '!=' => $disp_sid } } );

    # set-up test cases
    my %test_types  = (
            '1 No Refund' => {
                fields  => {
                    refund_type_id  => 0,
                    full_refund     => 1,
                },
                test_invoice_func   => \&_test_no_refund,
            },
            '2 Full Refund - Store Credit' => {
                amq_refund_type => 'CREDIT',
                fields  => {
                    refund_type_id  => 1,
                    full_refund     => 1,
                },
                test_invoice_func   => \&_test_full_refund,
            },
            '3 Not Full Refund - Credit Card' => {
                amq_refund_type => 'CARD',
                fields  => {
                    refund_type_id  => 99, # 99 forces this to be a card refund
                    full_refund     => 0,
                },
                wanted_refund_type_id => 2, # This should be the output type in the schema
                test_invoice_func   => \&_test_not_full_refund,
            },
            '4 Not Full Refund & No Tax - Store Credit' => {
                pre_run => \&_change_ship_country,
                amq_refund_type => 'CREDIT',
                fields  => {
                    refund_type_id  => 1,
                    full_refund     => 0,
                },
                test_invoice_func   => \&_test_not_full_refund_no_tax,
            },
        );
    my @tmp;
    my $amq_queue   = '/queue/'.lc( $channel->business->config_section . '-'
        . config_var('XTracker','instance') . '-orders' );

    note "TESTING Dispatch/Return";

    my $shipment_status     = $shipment->shipment_status_id;
    my $ship_item_status    = $shipment->shipment_items->search( { 'me.id' => { '!=' => $disp_sid } } )->first->shipment_item_status_id;

    foreach my $test ( sort keys %test_types ) {
        note "Test Type: ".$test;
        my $test_type   = $test_types{ $test };

        # run any pre test process
        $test_type->{pre_run}( $schema, $shipment )     if ( exists $test_type->{pre_run} );

        # clear the AMQ queue
        $amq->clear_destination( $amq_queue );

        $mech->get_ok( $mech->order_view_url );
        $mech->follow_link_ok( { text_regex => qr{Dispatch/Return} } );

        $mech->submit_form_ok({
            form_name => "cancelOrder",
            with_fields => $test_type->{fields},
            button  => 'submit',
        }, 'Dispatch/Return' );
        $mech->no_feedback_error_ok;
        $mech->has_feedback_success_ok(qr/Dispatch and Return completed successully/,"Shipment Dispatched & Returned");

        # check data out
        $shipment->discard_changes;
        my $return  = $shipment->return;
        cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DISPATCHED, 'Shipment Status as expected' );
        cmp_ok( $return->return_status_id, '==', $RETURN_STATUS__AWAITING_RETURN, 'Return Status as expected' );
        cmp_ok( $return->pickup, '==', 0, 'Pickup as expected' );
        ok( defined $return->creation_date, 'Creation Date not empty' );
        ok( defined $return->expiry_date, 'Expiry Date not empty' );
        ok( defined $return->cancellation_date, 'Cancellation Date not empty' );
        cmp_ok( $return->return_items->count(), '==', $expected_num_ret_items, 'Number of Return Items as expected' );
        my @items   = $shipment->shipment_items->all;
        my @amq_items;

        my $business_logic = XT::Business->new({ });
        my $plugin = $business_logic->find_plugin(
            $channel, 'Fulfilment'
        );

        foreach my $item ( @items ) {
            my $ret_item    = $item->return_item;
            my $variant = $item->variant;
            if ( $item->id == $disp_sid ) {
                # the dispatched item shouldn't have been returned
                ok( !defined $ret_item, 'No Return Item should have been created' );
                push @amq_items, superhashof({
                            sku             => ( defined $plugin ) ? $plugin->call('get_real_sku',$variant) : $variant->sku,
                            status          => 'Dispatched',
                            xtLineItemId    => $item->id,
                        });
            }
            else {
                cmp_ok( $item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__RETURN_PENDING, 'Shipment Item Status as expected' );
                cmp_ok( $ret_item->return_item_status_id, '==', $RETURN_ITEM_STATUS__AWAITING_RETURN, 'Return Item Status as expected' );
                cmp_ok( $ret_item->customer_issue_type_id, '==', $CUSTOMER_ISSUE_TYPE__7__DISPATCH_FSLASH_RETURN, 'Customer Issue as expected' );
                cmp_ok( $ret_item->return_type_id, '==', $RETURN_TYPE__RETURN, 'Return Type as expected' );
                cmp_ok( $ret_item->variant_id, '==', $item->variant_id, 'Variant Id matches' );
                push @amq_items, superhashof({
                            sku             => ( defined $plugin ) ? $plugin->call('get_real_sku',$variant) : $variant->sku,
                            status          => 'Return Pending',
                            returnReason    => 'DELIVERY_ISSUE',
                            xtLineItemId    => $item->id,
                            returnCreationDate=> napdate($ret_item->creation_date),
                        });
            }
        }
        $test_type->{test_invoice_func}( $shipment, $return, $test_type->{wanted_refund_type_id} || $test_type->{fields}{refund_type_id} );

        my $amq_order   = {
                rmaNumber               => $return->rma_number,
                returnExpiryDate        => napdate($return->expiry_date),
                returnCreationDate      => napdate($return->creation_date),
                returnCancellationDate  => napdate($return->cancellation_date),
                returnCutoffDate        => napdate($shipment->return_cutoff_date),
                status                  => 'Dispatched',
                orderItems              => bag(@amq_items),
            };
        if ( exists $test_type->{amq_refund_type} ) {
            $amq_order->{returnRefundType}  = $test_type->{amq_refund_type};
        }

        $amq->assert_messages({
            destination => $amq_queue,
            assert_header => superhashof({
                type => 'OrderMessage',
            }),
            assert_body => superhashof({
                '@type' => 'order',
                orderNumber => $shipment->order->order_nr,
                %{ $amq_order },
            }),
        }, 'Order Status sent on AMQ');

        # remove return from shipment so we can go round again
        if ( defined $return->renumerations->first ) {
            my $invoice = $return->renumerations->first;
            $invoice->renumeration_items->delete;
            $invoice->renumeration_status_logs->delete;
            $return->link_return_renumerations->delete;
            $invoice->renumeration_tenders->delete;
            $invoice->delete;
        }
        @tmp    = $return->return_items->all;
        map { $_->return_item_status_logs->delete } @tmp;
        $return->return_items->delete;
        $return->return_status_logs->delete;
        $return->delete;
        $shipment->discard_changes;
        @tmp    = $shipment->shipment_items->all;
        foreach ( @tmp ) {
            if ( $_->id != $disp_sid ) {
                $_->update( { shipment_item_status_id => $ship_item_status } );
            }
        }
        $shipment->update( { shipment_status_id => $shipment_status } );
    }

    return $mech;
}


#------------------------------------------------------------------------------------------------

# tests no refund specified
sub _test_no_refund {
    my $shipment    = shift;
    my $return      = shift;
    my $refund_type = shift;
        local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $invoice = $return->renumerations->first;
    ok( !defined $invoice, 'No Invoice (renumeration) created' );


    return;
}

# tests full refund specified
sub _test_full_refund {
    my $shipment    = shift;
    my $return      = shift;
    my $refund_type = shift;

    my @items;

    my $invoice = $return->renumerations->first;
    isa_ok( $invoice, 'XTracker::Schema::Result::Public::Renumeration', 'Invoice (renumeration) was created' );

    cmp_ok( $invoice->renumeration_type_id, '==', $refund_type, 'Refund Type as expected' );
    cmp_ok( $invoice->renumeration_class_id, '==', $RENUMERATION_CLASS__RETURN, 'Refund Class as expected' );
    cmp_ok( $invoice->renumeration_status_id, '==', $RENUMERATION_STATUS__PENDING, 'Refund Status as expected' );
    cmp_ok( $invoice->shipping, '==', $shipment->shipping_charge, 'Shipping Charge same as Shipment rec' );

    # go through all of the Invoice (renumeration) items
    @items  = $invoice->renumeration_items->all;
    foreach my $item ( @items ) {
        my $ship_item   = $shipment->shipment_items->find( $item->shipment_item_id );
        cmp_ok( $item->unit_price, '==', $ship_item->unit_price, 'Invoice Item Unit Price matches Shipment Item Unit Price' );
        cmp_ok( $item->tax, '==', $ship_item->tax, 'Invoice Item Tax matches Shipment Item Tax' );
        cmp_ok( $item->duty, '==', $ship_item->duty, 'Invoice Item Duty matches Shipment Item Duty' );
    }

    return;
}

# tests specified but no full refund flag
sub _test_not_full_refund {
    my $shipment    = shift;
    my $return      = shift;
    my $refund_type = shift;

    my @items;

    my $invoice = $return->renumerations->first;
    isa_ok( $invoice, 'XTracker::Schema::Result::Public::Renumeration', 'Invoice (renumeration) was created' );

    cmp_ok( $invoice->renumeration_type_id, '==', $refund_type, 'Refund Type as expected' );
    cmp_ok( $invoice->renumeration_class_id, '==', $RENUMERATION_CLASS__RETURN, 'Refund Class as expected' );
    cmp_ok( $invoice->renumeration_status_id, '==', $RENUMERATION_STATUS__PENDING, 'Refund Status as expected' );
    cmp_ok( $invoice->shipping, '==', 0, 'Shipping Charge not refunded' );

    # go through all of the Invoice (renumeration) items
    @items  = $invoice->renumeration_items->all;
    foreach my $item ( @items ) {
        my $ship_item   = $shipment->shipment_items->find( $item->shipment_item_id );
        cmp_ok( $item->unit_price, '==', $ship_item->unit_price, 'Invoice Item Unit Price matches Shipment Item Unit Price' );
        cmp_ok( $item->tax, '==', $ship_item->tax, 'Invoice Item Tax matches Shipment Item Tax' );
        cmp_ok( $item->duty, '==', $ship_item->duty, 'Invoice Item Duty matches Shipment Item Duty' );
    }

    return;
}

# tests specified but no full refund flag & no tax should be refunded
sub _test_not_full_refund_no_tax {
    my $shipment    = shift;
    my $return      = shift;
    my $refund_type = shift;

    my @items;

    my $invoice = $return->renumerations->first;
    isa_ok( $invoice, 'XTracker::Schema::Result::Public::Renumeration', 'Invoice (renumeration) was created' );

    cmp_ok( $invoice->renumeration_type_id, '==', $refund_type, 'Refund Type as expected' );
    cmp_ok( $invoice->renumeration_class_id, '==', $RENUMERATION_CLASS__RETURN, 'Refund Class as expected' );
    cmp_ok( $invoice->renumeration_status_id, '==', $RENUMERATION_STATUS__PENDING, 'Refund Status as expected' );
    cmp_ok( $invoice->shipping, '==', 0, 'Shipping Charge as expected' );

    # go through all of the Invoice (renumeration) items
    @items  = $invoice->renumeration_items->all;
    foreach my $item ( @items ) {
        my $ship_item   = $shipment->shipment_items->find( $item->shipment_item_id );
        cmp_ok( $item->unit_price, '==', $ship_item->unit_price, 'Invoice Item Unit Price matches Shipment Item Unit Price' );
        cmp_ok( $item->tax, '==', 0, 'Invoice Item Tax as expected' );
        cmp_ok( $item->duty, '==', 0, 'Invoice Item Duty as expected' );
    }

    return;
}

# flip the shipment country address so that no tax &/or duties should be applied when a refund is created
sub _change_ship_country {
    my $schema          = shift;
    my $shipment        = shift;

    $shipment->discard_changes;

    # update the shipping country with the new country
    $shipment->shipment_address->update( { country => Test::XTracker::Data->get_non_tax_duty_refund_state()->country } );

    return;
}


sub setup_user_perms {
  Test::XTracker::Data->grant_permissions($username, 'Customer Care', 'Order Search', 2);
  # Perms needed for the order process
  for (qw/Airwaybill Dispatch Packing Picking Selection Labelling/ ) {
    Test::XTracker::Data->grant_permissions($username, 'Fulfilment', $_, 2);
  }
  Test::XTracker::Data->grant_permissions($username, 'Fulfilment', 'Invalid Shipments', 2);
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
