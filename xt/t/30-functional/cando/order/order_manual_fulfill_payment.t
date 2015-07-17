#!/usr/bin/env perl

use NAP::policy     qw( test );

use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::XTracker::ParamCheck;

use XTracker::Constants         qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw( :channel );


BEGIN {
    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Database::OrderPayment', qw( toggle_payment_fulfilled_flag_and_log ));

    can_ok("XTracker::Database::OrderPayment", qw(
                            toggle_payment_fulfilled_flag_and_log
                        ) );
}

my $schema  = Test::XTracker::Data->get_schema;

# prepare data
my $order;
{
    my ($channel,$pids) = Test::XTracker::Data->grab_products();
    ($order) = Test::XTracker::Data->create_db_order({
        pids => $pids,
    });
    # make sure a Payment has been created for the Order
    $order->payments->delete;
    my $psp_refs = Test::XTracker::Data->get_new_psp_refs;
    Test::XTracker::Data->create_payment_for_order( $order, $psp_refs );
}

#---- Test Functions ------------------------------------------

_test_reqd_params($schema,1);
_test_toggle_func($schema,1);
_test_order_view_page( $schema, $order, 1 );

#--------------------------------------------------------------

done_testing();

#---- TEST FUNCTIONS ------------------------------------------

# Test that the functions are checking for required parameters
sub _test_reqd_params {
    my $schema  = shift;

    my $param_check = Test::XTracker::ParamCheck->new();

    my $max_id  = $schema->resultset('Orders::Payment')->search()->get_column('id')->max();

    SKIP: {
        skip "_test_reqd_params",1           if (!shift);

        note "Testing for Required Parameters";

        $param_check->check_for_params(  \&toggle_payment_fulfilled_flag_and_log,
                            'toggle_payment_fulfilled_flag_and_log',
                            [ $schema, $max_id, $APPLICATION_OPERATOR_ID, 'Test' ],
                            [ "No Schema Passed",
                              "No Payment Id Passed",
                              "No Operator Id Passed",
                              "No Reason Passed" ],
                            [ undef, ($max_id + 1) ],
                            [ undef, "Can't find Payment Record for Id: ".($max_id+1) ],
                        );
    }
}

# This tests the toggle function used to get toggle the fulfilled flag on the payment record
sub _test_toggle_func {
    my $schema  = shift;

    my $payment = $schema->resultset('Orders::Payment')->search()->first;
    my $log     = $payment->log_payment_fulfilled_changes_rs->search( undef, { order_by => 'me.id DESC' } );
    my $tmp;

    SKIP: {
        skip "_test_toggle_func",1           if (!shift);

        note "TESTING Toggle Function";
        $schema->txn_do( sub {
                # set-up the data for testing
                $payment->update( { fulfilled => 0 } );
                $log->delete_all;
                $log->reset;

                # set to TRUE
                cmp_ok( toggle_payment_fulfilled_flag_and_log( $schema, $payment->id, $APPLICATION_OPERATOR_ID, 'Test 1' ),
                        '==', 1, "Toggle Fulfilled Flag to TRUE" );
                $payment->discard_changes;
                $log->reset;
                $tmp    = $log->first->id;
                cmp_ok( $payment->fulfilled, '==', 1, 'Payment record shows Fulfilled Flag as being TRUE' );
                cmp_ok( $log->first->new_state, '==', 1, 'Log: New State Logged Correctly' );
                cmp_ok( $log->first->operator_id, '==', $APPLICATION_OPERATOR_ID, 'Log: Operator Logged Correctly' );
                is( $log->first->reason_for_change, 'Test 1', 'Log: Reason Logged Correctly' );

                # set to FALSE
                cmp_ok( toggle_payment_fulfilled_flag_and_log( $schema, $payment->id, $APPLICATION_OPERATOR_ID, 'Test 2' ),
                        '==', 0, "Toggle Fulfilled Flag to FALSE" );
                $payment->discard_changes;
                $log->reset;
                cmp_ok( $log->first->id, '>', $tmp, 'Newest Log Id is greater than previous' );
                cmp_ok( $payment->fulfilled, '==', 0, 'Payment record shows Fulfilled Flag as being FALSE' );
                cmp_ok( $log->first->new_state, '==', 0, 'Log: New State Logged Correctly' );
                cmp_ok( $log->first->operator_id, '==', $APPLICATION_OPERATOR_ID, 'Log: Operator Logged Correctly' );
                is( $log->first->reason_for_change, 'Test 2', 'Log: Reason Logged Correctly' );

                $schema->txn_rollback();
            } );
    }
}

# this tests the Order View Page displays the button properly
# for the designated list of users only but shows the log of changes
# for anyone in the Finance Department
sub _test_order_view_page {
    my ( $schema, $order_rec, $oktorun ) = @_;

    my $users   = $schema->resultset('SystemConfig::ConfigGroup')
                            ->search( { name => 'Finance_Manager_Users' } )
                                ->first;
    my $payrec  = $order_rec->payments->first;
    my $logrecs = $payrec->log_payment_fulfilled_changes_rs->search( undef, { order_by => 'me.id DESC' } );
    my $pageurl = '/CustomerCare/OrderSearch/OrderView?order_id=';

    my $tmp;

    SKIP: {
        skip "_test_order_view_page",1      if ( !$oktorun );

        note "TESTING Order View Page";
        note 'Payment Id: '.$payrec->id.', Orders Id: '.$payrec->orders_id;

        # set-up the data first
        $payrec->update( { fulfilled => 0 } );
        $logrecs->delete_all;
        $users->config_group_settings_rs->search( { 'me.value' => 'it.god' } )->delete;

        Test::XTracker::Data->set_department('it.god', 'Finance');
        Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);

        my $framework  = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Flow::CustomerCare',
                'Test::XT::Flow::Fulfilment',
            ],
        );
        my $mech = $framework->mech;
        $framework->login_with_permissions( {
            roles => {
                names => [
                    'app_canSearchOrders',
                    'app_canViewOrderPaymentDetails'
                ]
            },
        } );

        # it.god not in Finance Manager Users so shouldn't see the button
        $mech->get_ok( $pageurl.$payrec->orders_id );
        my $fulfill_log = _get_payfulfill_log( $mech );
        ok( !defined $fulfill_log, 'No Fulfilled Log Table Shown for empty log' );
        $tmp    = $mech->forms();
        cmp_ok( scalar( grep { $_ eq 'fulfillPayment' } @{ $tmp } ), '==', 0, 'No toggle button displayed' );

        # put it.god in the Finance Manager Users list, should see button and use it
        $users->config_group_settings_rs->create( {
                                                    setting     => 'user',
                                                    value       => 'it.god',
                                                    sequence    => ( $users->config_group_settings_rs->get_column('sequence')->max() + 1 ),
                                                  } );

        $mech->get_ok( $pageurl.$payrec->orders_id );
        $mech->submit_form_ok( {
            form_name   => 'fulfillPayment',
            button      => 'submit',
        }, 'Toggle the Fulfilled Flag to Yes' );
        $mech->no_feedback_error_ok;
        $payrec->discard_changes;
        $logrecs->reset;
        cmp_ok( $payrec->fulfilled, '==', 1, 'Payment Record has Fulfilled Flag as TRUE' );
        cmp_ok( $logrecs->count(), '==', 1, 'Fulfilled Log has 1 Record' );
        $tmp    = [ $mech->get_table_row( 'Fulfilled:' ) ];
        like( $tmp->[0], qr/Yes/, 'Fulfilled Value on Page is Showing Yes');
        $fulfill_log = _get_payfulfill_log( $mech );
        ok( $fulfill_log, 'Fulfilled Log Table Shown on Page' );
        cmp_ok( @{ $fulfill_log }, '>=', 1, 'Fulfilled Log Table has at least one row in it' );

        # toggle it to No
        $mech->submit_form_ok( {
            form_name   => 'fulfillPayment',
            button      => 'submit',
        }, 'Toggle the Fulfilled Flag to No' );
        $mech->no_feedback_error_ok;
        $payrec->discard_changes;
        $logrecs->reset;
        cmp_ok( $payrec->fulfilled, '==', 0, 'Payment Record has Fulfilled Flag as FALSE' );
        cmp_ok( $logrecs->count(), '==', 2, 'Fulfilled Log now has 2 Records' );
        $tmp    = [ $mech->get_table_row( 'Fulfilled:' ) ];
        like( $tmp->[0], qr/No/, 'Fulfilled Value on Page is Showing No');
        $fulfill_log = _get_payfulfill_log( $mech );
        ok( $fulfill_log, 'Fulfilled Log Table Still Shown on Page' );
        cmp_ok( @{ $fulfill_log }, '>=', 1, 'Fulfilled Log Table Still has at least one row in it' );

        # it.god user shouldn't be in this list so get rid of it
        $users->config_group_settings_rs->search( { 'me.value' => 'it.god' } )->delete;
        $mech->get_ok( $pageurl.$payrec->orders_id );
        $tmp    = $mech->forms();
        cmp_ok( scalar( grep { $_ eq 'fulfillPayment' } @{ $tmp } ), '==', 0, 'No toggle button displayed for Non Finance Manager User again' );
        $fulfill_log = _get_payfulfill_log( $mech );
        ok( $fulfill_log, 'Fulfilled Log Table Still Shown on Page for non Finance Manager Users' );
        cmp_ok( @{ $fulfill_log }, '>=', 1, 'and Fulfilled Log Table Still has at least one row in it' );

        note "Replace the existing 'Payment' record and check that the Payment Fulfill Logs are still shown";
        $payrec->discard_changes->copy_to_replacement_and_move_logs();
        # get new PSP Refs. and update the Payment record
        my $new_psp_refs = Test::XTracker::Data->get_new_psp_refs;
        $payrec->update( $new_psp_refs );
        $mech->get_ok( $pageurl.$payrec->orders_id );
        $fulfill_log = _get_payfulfill_log( $mech );
        ok( $fulfill_log, 'Fulfilled Log Table Still Shown on Page' );
        cmp_ok( @{ $fulfill_log }, '==', 2, 'and Fulfilled Log Table Still has the correct number of Rows in it' );
        like( $fulfill_log->[0]{'Pre-Auth Ref.'}, qr/\(previous\)/i, "and the First Row has 'previous' next to the Pre-Auth Reference" );

        note "Now Toggle the new Payment and check that BOTH logs are shown in Date descending order";
        # add back in it.god in the Finance Manager Users list
        $users->config_group_settings_rs->create( {
            setting     => 'user',
            value       => 'it.god',
            sequence    => ( $users->config_group_settings_rs->get_column('sequence')->max() + 1 ),
        } );
        $mech->get_ok( $pageurl.$payrec->orders_id );
        $mech->submit_form_ok( {
            form_name   => 'fulfillPayment',
            button      => 'submit',
        }, 'Toggle the Fulfilled Flag to Yes' );
        $fulfill_log = _get_payfulfill_log( $mech );
        ok( $fulfill_log, 'Fulfilled Log Table Still Shown on Page' );
        cmp_ok( @{ $fulfill_log }, '==', 3, 'and Fulfilled Log Table Still has Logs from the Original and New Payment' );
        like( $fulfill_log->[0]{'Pre-Auth Ref.'}, qr/\(current\)/i, "and the First Row has 'current' next to the Pre-Auth Reference" );
        like( $fulfill_log->[1]{'Pre-Auth Ref.'}, qr/\(previous\)/i, "but the second Row has 'previous' next to the Pre-Auth Reference" );
    }
}

#--------------------------------------------------------------

# get the Payment Fulfilled Log from the page
sub _get_payfulfill_log {
    my $mech = shift;

    my $pg_data = $mech->as_data();
    return $pg_data->{meta_data}{payment_fulfill_log};
}

