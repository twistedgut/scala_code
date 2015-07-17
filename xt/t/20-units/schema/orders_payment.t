#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Mock::PSP;

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :note_type
                                    );


use Test::Exception;
use Data::Dump qw( pp );


# evil globals
our ($schema);

BEGIN {
    use_ok('XTracker::Schema');
    use_ok('XTracker::Database',':common');
    use_ok('XTracker::Schema::Result::Orders::Payment');
    use_ok('XTracker::Schema::Result::Orders::LogPaymentFulfilledChange');
    use_ok('XTracker::Schema::ResultSet::Orders::Payment');
    can_ok('XTracker::Schema::Result::Orders::Payment', qw(
                                            create
                                            check_fulfilled
                                            invalidate
                                            validate
                                            set_preauth_reference
                                            fulfill
                                            toggle_fulfilled_flag
                                    ) );

}

# get a schema to query
$schema = get_database_handle(
    {
        name    => 'xtracker_schema',
    }
);
isa_ok($schema, 'XTracker::Schema',"Schema Created");

my $p_rs = $schema->resultset('Orders::Payment');
isa_ok($p_rs, 'XTracker::Schema::ResultSet::Orders::Payment', "Payment Result Set");
my $log_rs = $schema->resultset('Orders::LogPaymentFulfilledChange');
isa_ok($log_rs, 'DBIx::Class::ResultSet', "Log Payment Fulfilled Change Result Set");

$schema->txn_do( sub {
        my $tmp;
        my $data_in;

        # get 'it.god' operator
        my $itgod_op    = $schema->resultset('Public::Operator')->find( {username => 'it.god'}, {key => 'username'} );
        isa_ok( $itgod_op, "XTracker::Schema::Result::Public::Operator", "Found 'it.god' Operator record" );

        my($channel,$pids) = Test::XTracker::Data->grab_products({
            how_many => 1,
            dont_ensure_stock => 1,
            channel => Test::XTracker::Data->channel_for_nap(),
        });
        my ($order)=Test::XTracker::Data->create_db_order({
            pids => $pids,
            attr => [
                { price => 100, tax => 5, duty => 10 },
            ],
            base => {
                shipping_charge     => 10,
                tenders => [
                    { type => 'card_debit', value => 125 },
                ],
            },
        });
        my $next_preauth = Test::XTracker::Data->get_next_preauth( $schema->storage->dbh );

        my $p_rec   = Test::XTracker::Data->create_payment_for_order( $order, {
            psp_ref     => $next_preauth,
            preauth_ref => $next_preauth,
        } );
        isa_ok( $p_rec, 'XTracker::Schema::Result::Orders::Payment' );

        # update the fulfilled flag to a known state
        $p_rec->update( { fulfilled => 0 } );

        # test TRUE
        cmp_ok( $p_rec->toggle_fulfilled_flag, '==', 1, 'Toggle Fulfilled Flag to TRUE' );
        $p_rec->discard_changes;
        cmp_ok( $p_rec->fulfilled, '==', 1, 'Fulfilled Flag is actually TRUE' );

        # test FALSE
        cmp_ok( $p_rec->toggle_fulfilled_flag, '==', 0, 'Toggle Fulfilled Flag to FALSE' );
        $p_rec->discard_changes;
        cmp_ok( $p_rec->fulfilled, '==', 0, 'Fulfilled Flag is actually FALSE' );

        # create a log record for the fulfilled flag
        my $log_rec = $p_rec->create_related( 'log_payment_fulfilled_changes',
                                {
                                    new_state           => 1,
                                    operator_id         => $APPLICATION_OPERATOR_ID,
                                    reason_for_change   => 'Test',
                                } );
        isa_ok( $log_rec, 'XTracker::Schema::Result::Orders::LogPaymentFulfilledChange', 'Fulfilled Log Record Created' );

        # check there's a relationship between the
        # log table and the payment table
        $p_rec  = $log_rec->payment;
        isa_ok( $p_rec, 'XTracker::Schema::Result::Orders::Payment', 'Payment record found via Fulfilled Log record' );


        note "Testing 'log_payment_preauth_cancellation' related stuff, create 1 Succesful Cancellation and one Failed Attempt";

        # create a succesful Cancelation record for 'log_payment_preauth_cancellation'
        my $success_rec = $p_rec->create_related( 'log_payment_preauth_cancellations',
                                    {
                                        cancelled    => 1,
                                        preauth_ref_cancelled => $p_rec->preauth_ref,
                                        context     => 'Test Success',
                                        operator_id => $APPLICATION_OPERATOR_ID,
                                    } );
        # check there's a relationship between the
        # log table and the payment table
        $p_rec  = $success_rec->payment;
        isa_ok( $p_rec, 'XTracker::Schema::Result::Orders::Payment', 'Payment record found via Pre-Auth Cancelled Log record' );

        # create a un-succesful Cancelation record for 'log_payment_preauth_cancellation'
        my $failure_rec = $p_rec->create_related( 'log_payment_preauth_cancellations',
                                    {
                                        cancelled    => 0,
                                        preauth_ref_cancelled => $p_rec->preauth_ref,
                                        context     => 'Test Failure',
                                        message     => 'It Failed',
                                        operator_id => $APPLICATION_OPERATOR_ID,
                                    } );

        $log_rec    = $schema->resultset('Orders::LogPaymentPreauthCancellation')->get_preauth_cancelled_success( $p_rec->preauth_ref );
        cmp_ok( $log_rec->count, '==', 1, "Got 1 Succesful Cancelled Pre-Auth Log" );
        cmp_ok( $log_rec->first->cancelled, '==', 1, "Log's 'cancelled' flag is TRUE" );
        is( $log_rec->first->context, 'Test Success', "Log's 'context' is as expected" );

        $log_rec    = $schema->resultset('Orders::LogPaymentPreauthCancellation')->get_preauth_cancelled_failure( $p_rec->preauth_ref );
        cmp_ok( $log_rec->count, '==', 1, "Got 1 Un-Succesful Cancelled Pre-Auth Log" );
        cmp_ok( $log_rec->first->cancelled, '==', 0, "Log's 'cancelled' flag is TRUE" );
        is( $log_rec->first->context, 'Test Failure', "Log's 'context' is as expected" );

        $log_rec    = $schema->resultset('Orders::LogPaymentPreauthCancellation')->get_preauth_cancelled_attempts( $p_rec->preauth_ref );
        cmp_ok( $log_rec->count, '==', 2, "Got 2 Cancelled Pre-Auth Attempts Logs" );

        # check using the methods on 'Orders::Payment'
        _test_preauth_cancel_log_methods( $p_rec, 1, 1, 2 );
        note "now make the Success record a Failure";
        $success_rec->update( { cancelled => 0 } );
        _test_preauth_cancel_log_methods( $p_rec, 0, 2, 2 );
        note "now make the Success & Failure records both Successes";
        $success_rec->update( { cancelled => 1 } );
        $failure_rec->update( { cancelled => 1 } );
        _test_preauth_cancel_log_methods( $p_rec, 2, 0, 2 );
        note "now change the 'Pre-Auth' ref on the Payment Record only and check we get nothing back on all of them";
        $failure_rec->update( { cancelled => 0 } );      # put this back to how it was first
        my $next_next_preauth   = Test::XTracker::Data->get_next_preauth( $schema->storage->dbh );
        $p_rec->update( { preauth_ref => $next_next_preauth } );
        _test_preauth_cancel_log_methods( $p_rec, 0, 0, 0 );
        note "Change the 'Pre-Auth' ref back to what it was but remove all log records and check we get nothing back";
        $p_rec->update( { preauth_ref => $next_preauth } );
        $success_rec->delete;
        $failure_rec->delete;
        _test_preauth_cancel_log_methods( $p_rec, 0, 0, 0 );


        #
        # TESTING 'Orders::Payment::psp_cancel_preauth'
        #

        # cancel the PreAuth for the 'orders.payment' record
        note "Testing Cancelling the 'PreAuth' for the 'orders.payment' record";
        my $cancel_log_rs   = $p_rec->log_payment_preauth_cancellations->search( {}, { order_by => 'me.id DESC' } );

        # check if already fulfilled it doesn't cancel it
        $p_rec->update( { fulfilled => 1 } );
        $tmp    = $p_rec->psp_cancel_preauth;
        isa_ok( $tmp, 'HASH', "'psp_cancel_preauth' returned a HASH" );
        ok( !exists( $tmp->{success} ), "'success' not present in HASH" );
        cmp_ok( $tmp->{error}, '==', 2, "Attempt to Cancel a 'Fulfilled' Payment returned a Level 2 Error" );
        like( $tmp->{message}, qr/Pre-Auth already Fulfilled/, "Error Message also returned: $$tmp{message}" );
        is( $tmp->{context}, "Unknown", "HASH contains Context" );
        cmp_ok( $tmp->{operator_id}, '==', $APPLICATION_OPERATOR_ID, "HASH contains Operator Id" );
        cmp_ok( $cancel_log_rs->reset->count, '==', 0, "No 'log_payment_preauth_cancellations' records created" );
        $p_rec->update( { fulfilled => 0 } );   # set back to being non-fulfilled

        # check if already cancelled, create a pre-auth cancelled log record
        $success_rec    = $p_rec->create_related( 'log_payment_preauth_cancellations',
                                    {
                                        cancelled    => 1,
                                        preauth_ref_cancelled => $p_rec->preauth_ref,
                                        context     => 'Test Success',
                                        operator_id => $APPLICATION_OPERATOR_ID,
                                    } );
        $tmp    = $p_rec->discard_changes->psp_cancel_preauth;
        ok( !exists( $tmp->{success} ), "'success' not present in HASH" );
        cmp_ok( $tmp->{error}, '==', 2, "Attempt to Cancel a 'Cancelled' Pre-Auth returned a Level 2 Error" );
        like( $tmp->{message}, qr/Pre-Auth already Cancelled/, "Error Message also returned: $$tmp{message}" );
        cmp_ok( $cancel_log_rs->reset->count, '==', 1, "No more 'log_payment_preauth_cancellations' records created" );
        $success_rec->delete;       # get rid of log record
        $p_rec->discard_changes;

        # check for an undefined error
        note "check for an 'undefined' error";
        Test::XTracker::Mock::PSP->cancel_action( 'FAIL-undef' );
        $tmp    = $p_rec->psp_cancel_preauth;
        _check_psp_cancel_preauth_result( {
                                        response        => $tmp,
                                        cancel_log_rs   => $cancel_log_rs,
                                        log_count       => 1,
                                        message         => qr/Result from PSP came back Undefined/,
                                    } );
        $data_in= Test::XTracker::Mock::PSP->get_cancel_data_in();     # get the data sent to the PSP through 'psp_cancel_preauth'
        is_deeply( $data_in, { preAuthReference => $p_rec->preauth_ref }, "Data sent to the PSP through 'psp_cancel_preauth' as expected" );

        # check for a defined error
        note "check for a 'defined' error";
        Test::XTracker::Mock::PSP->cancel_action( 'FAIL-defined' );
        $tmp    = $p_rec->psp_cancel_preauth;
        _check_psp_cancel_preauth_result( {
                                        response        => $tmp,
                                        cancel_log_rs   => $cancel_log_rs,
                                        log_count       => 2,
                                        message         => "(-1) An Error Occured (Extra Reason for Failure) (Ref: FAIL_TEST_RESULT-$next_preauth)",
                                    } );
        $data_in= Test::XTracker::Mock::PSP->get_cancel_data_in();     # get the data sent to the PSP through 'psp_cancel_preauth'
        is_deeply( $data_in, { preAuthReference => $p_rec->preauth_ref }, "Data sent to the PSP through 'psp_cancel_preauth' as expected" );

        # check for no Extra reason or Reference in error message
        note "check for no Extra reason or Reference in error message";
        Test::XTracker::Mock::PSP->cancel_action( 'FAIL-no_reason_or_ref' );
        $tmp    = $p_rec->psp_cancel_preauth( { context => 'Test', operator_id => $itgod_op->id } );
        _check_psp_cancel_preauth_result( {
                                        response        => $tmp,
                                        cancel_log_rs   => $cancel_log_rs,
                                        log_count       => 3,
                                        message         => "(-1) An Error Occured",
                                        context         => 'Test',
                                        operator        => $itgod_op,
                                    } );

        # check a successful cancel
        note "check for a Successful Cancel";
        Test::XTracker::Mock::PSP->cancel_action( 'PASS' );
        $tmp    = $p_rec->psp_cancel_preauth( { context => 'Cancelling an Order', operator_id => $itgod_op->id } );
        ok( !exists( $tmp->{error} ), "'error' not present in HASH" );
        cmp_ok( $tmp->{success}, '==', 1, "Expecting a Success did return Success" );
        is( $tmp->{message}, "Ref: TEST_RESULT-$next_preauth", "Message came back with Reference" );
        cmp_ok( $cancel_log_rs->reset->count, '==', 4, "4 'log_payment_preauth_cancellations' records now exist" );
        cmp_ok( $cancel_log_rs->first->cancelled, '==', 1, "Log record has 'cancelled' flag set to TRUE" );
        is( $cancel_log_rs->first->context, "Cancelling an Order", "Log record 'context' is 'Cancelling an Order'" );
        cmp_ok( $cancel_log_rs->first->operator_id, '==', $itgod_op->id, "Log record 'operator_id' is for 'it.god'" );
        is( $cancel_log_rs->first->message, $tmp->{message}, "Log record 'message' same as Message returned" );

        #
        # TESTING 'Orders::Payment::psp_refund'
        #

        # Ensure extraReason is empty at the start of the tests.
        Test::XTracker::Mock::PSP->refund_extra( '' );
        $p_rec->update( { settle_ref => $next_preauth } );      # give it a Settle Ref

        # Test for success.

        my $refund_items = [ { sku => 'SKU', name => 'NAME', amount => 1234, vat => 56 } ];

        # Test zero refund is not acceptable
        throws_ok { $p_rec->psp_refund( 0, $refund_items ) }
            qr{Invalid amount given for creation of refund: 0},
            "psp_refund failed for zero refund amount";

        # Test a list of items that's not an ArrayRef is not acceptable.
        throws_ok { $p_rec->psp_refund( 100, \'Not An ArrayRef' ) }
            qr{Invalid list of items given for creation of refund: 100},
            'psp_refund failed when list of items is not an ArrayRef';

        Test::XTracker::Mock::PSP->refund_action( 'PASS' );
        lives_ok { $p_rec->psp_refund( 100, $refund_items ) } "psp_refund is succesful (doesn't die)";

        is_deeply(
            Test::XTracker::Mock::PSP->get_refund_data_in,
            {
                channel             => config_var('PaymentService_' . $order->channel->business->config_section, 'dc_channel'),
                coinAmount          => 10000, # Total value of order in pence.
                settlementReference => $p_rec->settle_ref,
                refundItems         => $refund_items,
            },
            "psp_refund is succesful (doesn't die) - received correct parameters"
        );

        # Setup failure tests.
        my $order_nr = $order->order_nr;
        my %psp_refund_tests = (
            'FAIL-2' => "Unable to refund for Order Nr: $order_nr,  The transaction has been rejected by the issuing bank\. Reason",
            'FAIL-3' => "Unable to refund for Order Nr: $order_nr,  Mandatory information missing from transaction\. Reason",
        );

        # Do the failure tests.
        while ( my ( $action, $result ) = each %psp_refund_tests ) {

            Test::XTracker::Mock::PSP->refund_action( $action );

            # Do the test with no extraReason.
            Test::XTracker::Mock::PSP->refund_extra( '' );
            throws_ok { $p_rec->psp_refund( 1, $refund_items ) } qr{$result: Could not find order via PSP Service<br>}, "psp_refund fails for $action with no extra reason (dies)";

            # Do the test with extraReason.
            Test::XTracker::Mock::PSP->refund_extra( 'Test Reason' );
            throws_ok { $p_rec->psp_refund( 1, $refund_items ) } qr{$result: Test Reason<br>}, "psp_refund fails for $action with extra reason 'Test Reason' (dies)";

        }

        #
        # TESTING 'Public::Orders::cancel_payment_preauth'
        #
        my $order_note_rs   = $order->discard_changes->order_notes->search( {}, { order_by => 'me.id DESC' } );

        # cancel an already cancelled Pre-Auth should do nothing
        note "check cancelling an already Cancelled payment which should bring back a level 2 error";
        $tmp    = $order->cancel_payment_preauth( { context => 'Cancelling an Order', operator_id => $itgod_op->id } );
        cmp_ok( $cancel_log_rs->reset->count, '==', 4, "Still 4 'log_payment_preauth_cancellations' records exist" );
        cmp_ok( $order_note_rs->reset->count, '==', 0, "No Order Note records created" );
        is_deeply( $tmp, {
                            error => 2,
                            message => 'Pre-Auth already Cancelled',
                            context => 'Cancelling an Order',
                            operator_id => $itgod_op->id,
                        }, "Response back from 'cancel_payment_preauth' as expected" );

        # check canceling a payment that fails
        # get rid of all log records first
        $cancel_log_rs->reset->delete;

        note "check cancelling a payment which fails";
        Test::XTracker::Mock::PSP->cancel_action( 'FAIL-defined' );
        $tmp    = $order->cancel_payment_preauth;
        cmp_ok( $order_note_rs->reset->count, '==', 1, "An Order Note record created" );
        cmp_ok( $order_note_rs->first->note_type_id, '==', $NOTE_TYPE__FINANCE, "Order Note Type is for Finance" );
        cmp_ok( $order_note_rs->first->operator_id, '==', $APPLICATION_OPERATOR_ID, "Order Note Operator is App. User" );
        is( $order_note_rs->first->note, "Cancel Payment Pre-Auth ($next_preauth) in context 'Unknown': FAILED",
                                "Order Note Note as expected: ".$order_note_rs->first->note );
        is_deeply( $tmp, {
                            error => 1,
                            message => "(-1) An Error Occured (Extra Reason for Failure) (Ref: FAIL_TEST_RESULT-$next_preauth)",
                            context => 'Unknown',
                            operator_id => $APPLICATION_OPERATOR_ID,
                        }, "Response back from 'cancel_payment_preauth' as expected" );

        # check cancelling a payment that succeeds
        note "check successfully cancelling a payment";
        Test::XTracker::Mock::PSP->cancel_action( 'PASS' );
        $tmp    = $order->cancel_payment_preauth( { context => 'Cancelling an Order', operator_id => $itgod_op->id } );
        cmp_ok( $order_note_rs->reset->count, '==', 2, "Two Order Note records now created" );
        cmp_ok( $order_note_rs->first->note_type_id, '==', $NOTE_TYPE__FINANCE, "Order Note Type is for Finance" );
        cmp_ok( $order_note_rs->first->operator_id, '==', $itgod_op->id, "Order Note Operator is it.god" );
        is( $order_note_rs->first->note, "Cancel Payment Pre-Auth ($next_preauth) in context 'Cancelling an Order': SUCCESSFUL",
                                "Order Note Note as expected: ".$order_note_rs->first->note );
        is_deeply( $tmp, {
                            success => 1,
                            message => "Ref: TEST_RESULT-$next_preauth",
                            context => 'Cancelling an Order',
                            operator_id => $itgod_op->id,
                        }, "Response back from 'cancel_payment_preauth' as expected" );



        #
        # TESTING 'Orders::Payment::[in]validate'
        #

        note 'checking [in]validate updates the payment records and creates a log entry';

        # Get the log object for this payment record and test it.
        my $valid_log_rs = $p_rec->log_payment_valid_changes;
        isa_ok( $valid_log_rs, 'DBIx::Class::ResultSet' );

        # Ensure an initial known state.
        $order->payments->update( { valid => 0 } );
        cmp_ok( $_->valid, '==', 0, 'Order Payment is initially invalid' ) foreach $order->payments->all;

        # Test the ResultSet method.
        test_order_payment( scalar $order->payments, $valid_log_rs, 1 );
        test_order_payment( scalar $order->payments, $valid_log_rs, 0 );

        # Test the individual record method.
        test_order_payment( $p_rec, $valid_log_rs, 1 );
        test_order_payment( $p_rec, $valid_log_rs, 0 );

        #
        # CLEANUP
        #

        # now git rid of the payment record completely
        note "check calling 'cancel_payment_preauth' when there are no payments to cancel";
        $p_rec->log_payment_fulfilled_changes->delete;  # delete all Fulfilled logs
        $cancel_log_rs->reset->delete;                  # delete all logs
        $order_note_rs->reset->delete;                  # delete all order notes
        $valid_log_rs->delete;                          # delete all validity change logs
        $p_rec->discard_changes->delete;                # delete the payment record

        lives_ok( sub {
                $tmp = $order->cancel_payment_preauth( { context => 'Cancelling an Order', operator_id => $itgod_op->id } );
            }, "Call to 'cancel_payment_preauth' to cancel nothing is ok" );
        ok( !defined $tmp, "Response back from method is 'undefined'" );
        cmp_ok( $order_note_rs->reset->count, '==', 0, "There are no Order Notes" );
        cmp_ok( $cancel_log_rs->reset->count, '==', 0, "Zero 'log_payment_preauth_cancellations' records exist" );

        # rollback any changes to the database
        $schema->txn_rollback();
    } );


done_testing();


#----------------------------------------------------------------------------------------------------------

# helper to test that the 'psp_cancel_preauth' method
# does what it's supposed to do
sub _check_psp_cancel_preauth_result {
    my $args    = shift;

    my $response        = $args->{response};
    my $cancel_log_rs   = $args->{cancel_log_rs};
    my $message         = $args->{message};
    my $operator_id     = ( defined $args->{operator} ? $args->{operator}->id : $APPLICATION_OPERATOR_ID );
    my $operator_name   = ( defined $args->{operator} ? $args->{operator}->username : "App. User" );
    my $context         = $args->{context} || "Unknown";

    isa_ok( $response, "HASH", "HASH returned by 'psp_cancel_preauth'" );
    ok( !exists( $response->{success} ), "'success' not present in HASH" );
    cmp_ok( $response->{error}, '==', 1, "Expecting an Error did return a Level 1 Error" );
    if ( ref( $message ) ) {
        like( $response->{message}, $message, "Got Expected Error Message: $$response{message}" );
    }
    else {
        is( $response->{message}, $message, "Got Expected Error Message: $$response{message}" );
    }
    is( $response->{context}, $context, "Context is in HASH" );
    cmp_ok( $response->{operator_id}, '==', $operator_id, "Operator Id is in HASH" );
    cmp_ok( $cancel_log_rs->reset->count, '==', $args->{log_count}, "$$args{log_count} 'log_payment_preauth_cancellations' records now exist" );
    cmp_ok( $cancel_log_rs->first->cancelled, '==', 0, "Log record has 'cancelled' flag set to FALSE" );
    is( $cancel_log_rs->first->context, $context, "Log record 'context' is '$context'" );
    cmp_ok( $cancel_log_rs->first->operator_id, '==', $operator_id, "Log record 'operator_id' is for '$operator_name'" );
    is( $cancel_log_rs->first->message, $response->{message}, "Log record 'message' same as Error Message returned" );
}

# helper to test 'preauth_cancelled', 'preauth_cancelled_failure' & 'preauth_cancelled_attempted'
# methods on a 'Schema::Result::Orders::Payment' record
sub _test_preauth_cancel_log_methods {
    my ( $p_rec, $success, $failure, $attempts )    = @_;

    $p_rec->discard_changes;

    cmp_ok( $p_rec->preauth_cancelled, '==', $success, "Using Orders::Payment 'preauth_cancelled' method returns '$success'" );
    cmp_ok( $p_rec->preauth_cancelled_failure, '==', $failure, "Using Orders::Payment 'preauth_cancelled_failure' method returns '$failure'" );
    cmp_ok( $p_rec->preauth_cancelled_attempted, '==', $attempts, "Using Orders::Payment 'preauth_cancelled_attempted' method returns '$attempts'" );
}

sub test_order_payment {
    my ( $object, $logs, $expected_state ) = @_;

    my $object_ref = ref $object;
    my $method     = {
        0 => 'invalidate',
        1 => 'validate'
    }->{ $expected_state };

    isnt( $object_ref, '', 'We have an object' );
    isnt( $method, undef, 'Method has been determined' );

    subtest "$object_ref->$method" => sub {

        my $object_count;
        my $object_all;

        given ( $object_ref ) {

            when ( 'XTracker::Schema::Result::Orders::Payment' ) {
            # If we've bee given a single record.

                $object_count = 1;
                $object_all   = sub { return ( $object ) };

            }

            when ( 'XTracker::Schema::ResultSet::Orders::Payment' ) {
            # If we've been given an entire resultset.

                $object_count = $object->count;
                $object_all   = sub { return $object->all };

            }

            default {
            # We only accept one of the above.

                fail 'Object is of a valid type';

            }

        }

        cmp_ok( $object_count, '>=', 0, 'We have some payments to work with' );

        # Record the IDs of the already existing log entries.
        my @log_ids = $logs->get_column('id')->all;

        # Test the resultset validate method.
        lives_ok { $object->$method } "Object method $method called sucessfully";

        # Get the new log entries.
        my $new_logs = $logs->search( { id => { '-not_in' => \@log_ids } } );
        isa_ok( $new_logs, 'DBIx::Class::ResultSet' );

        # Test we have the right number of new log entries and they have the correct state.
        cmp_ok( $new_logs->count, '==', $object_count, 'We added the correct number of log entries' );
        cmp_ok( $_->new_state, '==', $expected_state, "Log entry is now ${method}d" ) foreach $new_logs->all;

        # Test the payments now have the correct state.
        cmp_ok( $_->valid, '==', $expected_state, "Payment record is now ${method}d" ) foreach $object_all->();

    }

}
