#!/usr/bin/env perl
use NAP::policy "tt", 'test';

=head2 Test 'Public::Orders' Methods

This tests various methods on the 'Orders' object:

* add_flag
* add_flag_once
* should_put_onhold_for_signature_optout
* put_on_credit_hold_for_signature_optout

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::RunCondition export => [ '$distribution_centre' ];

use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw(
                                            :customer_class
                                            :currency
                                            :flag
                                            :order_status
                                            :shipment_status
                                        );
use XTracker::Config::Local;


use Test::Exception;
use Data::Dump  qw( pp );
use DateTime;

# get a schema to query
my $schema  = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");
my $dbh = $schema->storage->dbh;


$schema->txn_do( sub {

        my ( $channel, $order ) = _create_order();

        # Test get_standard_class_shipment_address_country
        cmp_ok(
            $order->get_standard_class_shipment_address_country,
            'eq',
            config_var( 'DistributionCentre', 'country' ),
            'get_standard_class_shipment_address_country returns the correct country'
        );

        my $psp_refs    = Test::XTracker::Data->get_new_psp_refs();
        Test::XTracker::Data->create_payment_for_order( $order, $psp_refs );

        my $shipment    = $order->shipments->first;
        my $ship_item   = $shipment->shipment_items->first;
        my $customer    = $order->customer;

        _check_required_params( $order );

        # get customer categories to use in tests
        my $eip_category    = $schema->resultset('Public::CustomerClass')
                                    ->search( { id => $CUSTOMER_CLASS__EIP } )->first
                                        ->customer_categories->first;
        my $non_eip_category= $schema->resultset('Public::CustomerClass')
                                    ->search( { id => { '!=' => $CUSTOMER_CLASS__EIP } } )->first
                                        ->customer_categories->first;


        note "testing 'add_flag' & 'add_flag_once'";

        my $order_flags = $order->order_flags->search( {}, { order_by => 'id DESC' } );
        $order_flags->delete;       # delete any existing flags

        $order->add_flag( $FLAG__DELIVERY_SIGNATURE_OPT_OUT );
        cmp_ok( $order_flags->reset->first->flag_id, '==', $FLAG__DELIVERY_SIGNATURE_OPT_OUT,
                                                    "Flag was created using 'add_flag'" );
        my $tmp = $order_flags->reset->first->id;   # store the Id

        # tests that creating the same flag again does create a new flag
        $order->add_flag( $FLAG__DELIVERY_SIGNATURE_OPT_OUT );
        cmp_ok( $order_flags->reset->first->id, '>', $tmp, "Another Flag was created using 'add_flag'" );

        # delete the flags again and use 'add_flag_once'
        $order_flags->delete;
        $order->add_flag_once( $FLAG__DELIVERY_SIGNATURE_OPT_OUT );
        cmp_ok( $order_flags->reset->first->flag_id, '==', $FLAG__DELIVERY_SIGNATURE_OPT_OUT,
                                                    "Flag was created using 'add_flag_once'" );
        $tmp    = $order_flags->reset->first->id;   # store the Id
        # tests that creating the same flag again does NOT create a new flag
        $order->add_flag_once( $FLAG__DELIVERY_SIGNATURE_OPT_OUT );
        cmp_ok( $order_flags->reset->first->id, '==', $tmp, "Trying to add the same Flag again using 'add_flag_once' doesn't create a new record" );


        note "testing 'should_put_onhold_for_signature_optout' method";

        # set a threshold
        my $threshold   = Test::XTracker::Data->set_delivery_signature_threshold( $channel, $order->currency, 2000 );

        # set-up tests to do
        my $config  = \%XTracker::Config::Local::config;
        my %tests   = (
                'Over Threshold'        => {
                        amount => $threshold + 10,
                        customer_category => $non_eip_category->id,
                        result => 1,   # should be true
                    },
                'Over Threshold - EIP'  => {
                        amount => $threshold + 10,
                        customer_category => $eip_category->id,
                        result => 0,   # should be false
                    },
                'On Threshold'         => {
                        amount => $threshold,
                        customer_category => $non_eip_category->id,
                        result => 1,   # should be true
                    },
                'Under Threshold'       => {
                        amount => $threshold - 10,
                        customer_category => $non_eip_category->id,
                        result => 0,   # should be false
                    },
            );

        $config->{DistributionCentre}{has_delivery_signature_optout} = 'yes';
        _run_should_put_onhold_for_signature_optout_test( "run tests with Config Setting set to 'yes'", $order, \%tests );

        $config->{DistributionCentre}{has_delivery_signature_optout} = 'no';
        map { $tests{ $_ }{result} = 0 } keys %tests;       # set every test to expect FALSE
        _run_should_put_onhold_for_signature_optout_test( "run tests with Config Setting set to 'no'", $order, \%tests );

        # this is DC1 conditions
        Test::XTracker::Data->remove_config_group( 'No_Delivery_Signature_Credit_Hold_Threshold' );
        _run_should_put_onhold_for_signature_optout_test( "run tests with Config Setting set to 'no' & no Thresholds in the DB", $order, \%tests );


        note "testing 'put_on_credit_hold_for_signature_optout' method";

        # fix the data so it should go on hold
        $config->{DistributionCentre}{has_delivery_signature_optout} = 'yes';
        $threshold  = Test::XTracker::Data->set_delivery_signature_threshold( $channel, $order->currency, 2000 );
        $customer->update( { category_id => $non_eip_category->id } );
        $shipment->shipment_items->update( { unit_price => $threshold + 10 } );

        my %order_statuses      = map { $_->id => $_ } $schema->resultset('Public::OrderStatus')->all;
        my %shipment_statuses   = map { $_->id => $_ } $schema->resultset('Public::ShipmentStatus')->all;

        %tests  = (
                'Signature Set to TRUE' => {
                        result          => 0,
                        signature_flag  => 1,
                        update_status   => sub {
                                            $order->discard_changes->update( { order_status_id => $ORDER_STATUS__ACCEPTED } );
                                            $shipment->discard_changes->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );
                                        },
                        status_list     => [ 'Run Once' ],
                    },
                'Signature Set to FALSE' => {
                        result          => 1,
                        signature_flag  => 0,
                        update_status   => sub {
                                            $order->discard_changes->update( { order_status_id => $ORDER_STATUS__ACCEPTED } );
                                            $shipment->discard_changes->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );
                                        },
                        status_list     => [ 'Run Once' ],
                    },
                'Different Order Status - Should be Put On Hold' => {
                        result          => 1,
                        signature_flag  => 0,
                        update_status   => sub {
                                            $order->discard_changes->update( { order_status_id => shift } );
                                            $shipment->discard_changes->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );
                                        },
                        # only have the Statuses we want
                        status_list     => [ map { delete $order_statuses{ $_ } } ( $ORDER_STATUS__ACCEPTED ) ],
                    },
                'Different Order Status - Should NOT be Put On Hold' => {
                        result          => 0,
                        signature_flag  => 0,
                        update_status   => sub {
                                            $order->discard_changes->update( { order_status_id => shift } );
                                            $shipment->discard_changes->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );
                                        },
                        # get all that's left
                        status_list     => [ values %order_statuses ],
                    },
                'Different Shipment Status - Should be Put On Hold' => {
                        result          => 1,
                        signature_flag  => 0,
                        update_status   => sub {
                                            $shipment->discard_changes->update( { shipment_status_id => shift } );
                                            $order->discard_changes->update( { order_status_id => $ORDER_STATUS__ACCEPTED } );
                                        },
                        # only have the Statuses we want
                        status_list     => [ map { delete $shipment_statuses{ $_ } } (
                                                                            $SHIPMENT_STATUS__PROCESSING,
                                                                            $SHIPMENT_STATUS__HOLD,
                                                                            $SHIPMENT_STATUS__DDU_HOLD
                                                                        ) ],
                    },
                'Different Shipment Status - Should NOT be Put On Hold' => {
                        result          => 0,
                        signature_flag  => 0,
                        update_status   => sub {
                                            $shipment->discard_changes->update( { shipment_status_id => shift } );
                                            $order->discard_changes->update( { order_status_id => $ORDER_STATUS__ACCEPTED } );
                                        },
                        # get all that's left
                        status_list     => [ values %shipment_statuses ],
                    },
            );

        # run using the Shipment Object
        _run_put_onhold_for_signature_optout_test( "Using Shipment Object - Check Nothing Happens when Signature Flag is TRUE", $order,
                                                                                        $tests{'Signature Set to TRUE'} );
        _run_put_onhold_for_signature_optout_test( "Using Shipment Object - Check Order is put on Hold when Signature Flag is FALSE", $order,
                                                                                        $tests{'Signature Set to FALSE'} );

        # now run again using the Shipment Id instead of the Shipment Object
        $tests{'Signature Set to TRUE'}{shipment_id}    = $shipment->id;
        $tests{'Signature Set to FALSE'}{shipment_id}   = $shipment->id;
        _run_put_onhold_for_signature_optout_test( "Using Shipment Id - Check Nothing Happens when Signature Flag is TRUE", $order,
                                                                                        $tests{'Signature Set to TRUE'} );
        _run_put_onhold_for_signature_optout_test( "Using Shipment Id - Check Order is put on Hold when Signature Flag is FALSE", $order,
                                                                                        $tests{'Signature Set to FALSE'} );

        note "check Different Order Statuses are put on Hold or Not";
        _run_put_onhold_for_signature_optout_test( "Check Order Statuses that will be Put On Hold", $order,
                                                                                        $tests{'Different Order Status - Should be Put On Hold'} );
        _run_put_onhold_for_signature_optout_test( "Check Order Statuses that will NOT be Put On Hold", $order,
                                                                                        $tests{'Different Order Status - Should NOT be Put On Hold'} );
        note "check Different Shipment Statuses are put on Hold or Not";
        _run_put_onhold_for_signature_optout_test( "Check Shipment Statuses that will be Put On Hold", $order,
                                                                                        $tests{'Different Shipment Status - Should be Put On Hold'} );
        _run_put_onhold_for_signature_optout_test( "Check Shipment Statuses that will NOT be Put On Hold", $order,
                                                                                        $tests{'Different Shipment Status - Should NOT be Put On Hold'} );


        my $pre_order_order = Test::XTracker::Data::PreOrder->create_order_linked_to_pre_order();
        note "testing 'order_check_payment' method";

        %tests  = (
                'Normal Order with Payment NOT Fulfilled'   => {
                        expected_result => 0,
                        order_obj       => $order,
                        do_pre_test     => sub {
                                my $order   = shift->discard_changes;
                                my $payment = $order->payments->first;
                                $payment->update( { fulfilled => 0 } );
                                return;
                            },
                    },
                'Normal Order with Payment Fulfilled'   => {
                        expected_result => 1,
                        order_obj       => $order,
                        do_pre_test     => sub {
                                my $order   = shift->discard_changes;
                                my $payment = $order->payments->first;
                                $payment->update( { fulfilled => 1 } );
                                return;
                            },
                    },
                'Pre-Order Order with Payment NOT Fulfilled & NOT Yet Packed' => {
                        expected_result => 0,
                        order_obj       => $pre_order_order,
                        do_pre_test     => sub {
                                my $order   = shift->discard_changes;
                                my $payment = $order->payments->first;
                                $payment->update( { fulfilled => 0 } );
                                $order->link_orders__shipments
                                        ->search_related('shipment')
                                            ->update( { has_packing_started => 0 } );
                                return;
                            },
                    },
                'Pre-Order Order with Payment Fulfilled & NOT Yet Packed' => {
                        expected_result => 0,
                        order_obj       => $pre_order_order,
                        do_pre_test     => sub {
                                my $order   = shift->discard_changes;
                                my $payment = $order->payments->first;
                                $payment->update( { fulfilled => 1 } );
                                $order->link_orders__shipments
                                        ->search_related('shipment')
                                            ->update( { has_packing_started => 0 } );
                                return;
                            },
                    },
                'Pre-Order Order with Payment NOT Fulfilled & Packing Started' => {
                        expected_result => 0,
                        order_obj       => $pre_order_order,
                        do_pre_test     => sub {
                                my $order   = shift->discard_changes;
                                my $payment = $order->payments->first;
                                $payment->update( { fulfilled => 0 } );
                                $order->link_orders__shipments
                                        ->search_related('shipment')
                                            ->update( { has_packing_started => 1 } );
                                return;
                            },
                    },
                'Pre-Order Order with Payment Fulfilled & Packing Started' => {
                        expected_result => 1,
                        order_obj       => $pre_order_order,
                        do_pre_test     => sub {
                                my $order   = shift->discard_changes;
                                my $payment = $order->payments->first;
                                $payment->update( { fulfilled => 1 } );
                                $order->link_orders__shipments
                                        ->search_related('shipment')
                                            ->update( { has_packing_started => 1 } );
                                return;
                            },
                    },
            );

        foreach my $label ( keys %tests ) {
            note "test: $label";
            my $test    = $tests{ $label };

            my $expected    = $test->{expected_result};
            my $test_suffix = ( $expected ? 'TRUE' : 'FALSE' );

            my $order_obj   = $test->{order_obj};
            $test->{do_pre_test}->( $order_obj );
            my $got = $order_obj->order_check_payment();

            cmp_ok( $got, '==', $expected, "method returned as Expected: $test_suffix" );
        }

        _test_is_customers_nth_order();

        # rollback changes
        $schema->txn_rollback();
    } );

done_testing;

#-----------------------------------------------------------------------------------------

# run tests against the 'should_put_onhold_for_signature_optout' method
sub _run_should_put_onhold_for_signature_optout_test {
    my ( $label, $order, $tests )   = @_;

    note "should_put_onhold_for_signature_optout - $label";

    $order->discard_changes;
    my $customer    = $order->customer;
    my $shipment    = $order->shipments->first;
    my $ship_item   = $shipment->shipment_items->first;

    foreach my $test_label ( sort keys %{ $tests } ) {
        note "test: $test_label";
        my $test    = $tests->{ $test_label };
        my $result  = $test->{result};

        # set the conditions
        $customer->discard_changes->update( { category_id => $test->{customer_category} } );
        # make sure the amount is spread over Shipping Charge, Unit Price, Tax & Duty
        $shipment->discard_changes->update( { shipping_charge => 20 } );
        $ship_item->discard_changes->update( { unit_price => $test->{amount} - 45, tax => 10, duty => 15 } );
        $order->discard_changes;

        cmp_ok( $order->should_put_onhold_for_signature_optout( $shipment ), '==', $result,
                                            "Got Expected Result with passing in a 'Public::Shipment' object: $result" );
        cmp_ok( $order->should_put_onhold_for_signature_optout( $shipment->id ), '==', $result,
                                            "Got Expected Result with passing in a 'Shipment Id': $result" );
    }

    return;
}

# run tests against the 'put_on_credit_hold_for_signature_optout' method
sub _run_put_onhold_for_signature_optout_test {
    my ( $label, $order, $test )    = @_;

    note "put_on_credit_hold_for_signature_optout - $label";

    $order->discard_changes;
    my $shipment    = $order->shipments->first;

    # used to get the logs later
    my $ord_log_rs  = $order->order_status_logs->search( {}, { order_by => 'id DESC' } );
    my $shp_log_rs  = $shipment->shipment_status_logs->search( {}, { order_by => 'id DESC' } );
    my $ord_flags   = $order->order_flags->search( { flag_id => $FLAG__DELIVERY_SIGNATURE_OPT_OUT } );

    # remember how many logs there are
    my $order_logs  = $order->order_status_logs->count;
    my $ship_logs   = $shipment->shipment_status_logs->count;

    # clear any Order Flags
    $order->order_flags->delete;

    # fix the data how the test demands
    $shipment->update( { signature_required => $test->{signature_flag} } );

    foreach my $status ( @{ $test->{status_list} } ) {
        # if the tests are to be run multiple times then
        # update the appropriate statuses
        if ( $status ne 'Run Once' ) {
            note "Using Status: ".$status->status;
            $status = $status->id;
        }

        # update the statues accordingly
        $test->{update_status}( $status );
        $order->discard_changes;
        $shipment->discard_changes;

        # remember the statuses
        my $order_status= $order->order_status_id;
        my $ship_status = $shipment->shipment_status_id;

        # call the method and get the result back
        my $result  = $order->put_on_credit_hold_for_signature_optout( (
                                                                        defined $test->{shipment_id}
                                                                        ? $test->{shipment_id}
                                                                        : $shipment
                                                                       ), $APPLICATION_OPERATOR_ID );

        if ( $test->{result} ) {
            cmp_ok( $result, '==', 1, "method returned TRUE" );
            cmp_ok( $order->discard_changes->order_status_logs->count, '==', $order_logs + 1, "One New Order Status Log Created" );
            cmp_ok( $shipment->discard_changes->shipment_status_logs->count, '==', $ship_logs + 1, "One New Shipment Status Log Created" );
            cmp_ok( $order->order_status_id, '==', $ORDER_STATUS__CREDIT_HOLD, "Order Status is now 'Credit Hold'" );
            cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__FINANCE_HOLD, "Shipment Status is now 'Finance Hold'" );
            cmp_ok( $ord_log_rs->reset->first->order_status_id, '==', $ORDER_STATUS__CREDIT_HOLD, "Order Status Log Shows 'Credit Hold'" );
            cmp_ok( $shp_log_rs->reset->first->shipment_status_id, '==', $SHIPMENT_STATUS__FINANCE_HOLD, "Shipment Status Log Shows 'Finance Hold'" );
            cmp_ok( $ord_flags->reset->count, '==', 1, "The Order Flag has been Assigned" );

            # increase the log counts
            $order_logs++;
            $ship_logs++;
        }
        else {
            cmp_ok( $result, '==', 0, "method returned FALSE" );
            cmp_ok( $order->discard_changes->order_status_logs->count, '==', $order_logs, "No New Order Status Logs" );
            cmp_ok( $shipment->discard_changes->shipment_status_logs->count, '==', $ship_logs, "No New Shipment Status Logs" );
            cmp_ok( $order->order_status_id, '==', $order_status, "Order Status still the Same" );
            cmp_ok( $shipment->shipment_status_id, '==', $ship_status, "Shipment Status still the Same" );
            cmp_ok( $ord_flags->reset->count, '==', 0, "No Order Flag has been Assigned" );
        }
    }

    return;
}

# run tests on methods to check required parameters are passed in
sub _check_required_params {
    my $order   = shift;

    note "Checking for Required Parameters passed to Methods";

    note "method: should_put_onhold_for_signature_optout";
    dies_ok( sub {
            $order->should_put_onhold_for_signature_optout();
        }, "'should_put_onhold_for_signature_optout' passed no Shipment dies correctly" );
    chomp($@);
    like( $@, qr/was passed with no 'Shipment'/, "Error Message Correct ($@)" );
    dies_ok( sub {
            $order->should_put_onhold_for_signature_optout( -1 );
        }, "'should_put_onhold_for_signature_optout' passed invalid Shipment Id dies correctly" );
    chomp($@);
    like( $@, qr/coulnd't find a Shipment for the Id: -1/, "Error Message Correct ($@)" );
    dies_ok( sub {
            $order->should_put_onhold_for_signature_optout( $order );
        }, "'should_put_onhold_for_signature_optout' passed invalid Shipment Object dies correctly" );
    chomp($@);
    like( $@, qr/was not passed a 'Public::Shipment' object but a 'XTracker::Schema::Result::Public::Orders'/, "Error Message Correct ($@)" );

    note "method: put_on_credit_hold_for_signature_optout";
    dies_ok( sub {
            $order->put_on_credit_hold_for_signature_optout();
        }, "'put_on_credit_hold_for_signature_optout' passed no Shipment dies correctly" );
    chomp($@);
    like( $@, qr/was passed with no 'Shipment'/, "Error Message Correct ($@)" );
    dies_ok( sub {
            $order->put_on_credit_hold_for_signature_optout( 1 );
        }, "'put_on_credit_hold_for_signature_optout' passed no Operator Id dies correctly" );
    chomp($@);
    like( $@, qr/was passed with no 'Operator Id'/, "Error Message Correct ($@)" );
    dies_ok( sub {
            $order->put_on_credit_hold_for_signature_optout( -1, $APPLICATION_OPERATOR_ID );
        }, "'put_on_credit_hold_for_signature_optout' passed invalid Shipment Id dies correctly" );
    chomp($@);
    like( $@, qr/coulnd't find a Shipment for the Id: -1/, "Error Message Correct ($@)" );
    dies_ok( sub {
            $order->put_on_credit_hold_for_signature_optout( $order, $APPLICATION_OPERATOR_ID );
        }, "'put_on_credit_hold_for_signature_optout' passed invalid Shipment Object dies correctly" );
    chomp($@);
    like( $@, qr/was not passed a 'Public::Shipment' object but a 'XTracker::Schema::Result::Public::Orders'/, "Error Message Correct ($@)" );

    return;
}

sub _test_is_customers_nth_order {

    note 'testing is_customers_nth_order';

    my @orders;
    my $offset = $schema->resultset('Public::Channel')->count;

    # Create a customer and order on each channel.
    foreach my $channel ( $schema->resultset('Public::Channel')->all ) {

        my $new_customer = Test::XTracker::Data->create_dbic_customer( {
            # Use the same email address for all the orders, so they will
            # be for the same customer.
            email      => 'is_customers_nth_order@net-a-porter.com',
            channel_id => $channel->id,
        } );

        my $new_order = _create_order(
            customer_id => $new_customer->id,
            date        => DateTime->now->subtract( days => $offset-- )
        );

        # We'll be testing these in order.
        push @orders, $new_order;

    }

    # For each of the above orders.
    foreach my $order1 ( 1 .. ( $#orders + 1 ) ) {

        # Check it against all the other orders (including itself).
        foreach my $order2 ( 1 .. ( $#orders + 1 ) ) {

            if ( $order2 == $order1 ) {
            # If it's the same order, it should return TRUE.

                ok(
                    $orders[ $order1 - 1 ]->is_customers_nth_order( $order2 ),
                    "is_customers_nth_order( $order2 ) returns true for order number $order1"
                );

            } else {
            # Otherwise it should return FALSE.

                ok(
                    ! $orders[ $order1 - 1 ]->is_customers_nth_order( $order2 ),
                    "is_customers_nth_order( $order2 ) returns false for order number $order1"
                );

            }

        }

    }

}


sub _create_order {
    my ( %parameters ) = @_;

    # Make sure the order is from a known country.
    my $invoice_address = Test::XTracker::Data->order_address( {
        address => 'create',
        country => config_var( 'DistributionCentre', 'country' ),
    } );

    my $currency = $schema->resultset('Public::Currency')->find( {
        currency => config_var( 'Currency', 'local_currency_code' ),
    } );

    my ( $channel, $pids ) = Test::XTracker::Data->grab_products( {
        how_many          => 1,
        dont_ensure_stock => 1,
    } );

    my ( $order ) = Test::XTracker::Data->create_db_order( {
        pids => $pids,
        base => {
            shipping_charge => 10,
            currency_id     => ( $currency ? $currency->id : $CURRENCY__GBP ),
            invoice_address_id => $invoice_address->id,
            tenders         => [ {
                type  => 'card_debit',
                value => 110
            } ],
            %parameters,
        },
        attrs => [ {
            price => 100.00,
            tax   => 0,
            duty  => 0
        } ],
    } );

    return ( $channel, $order );

}
