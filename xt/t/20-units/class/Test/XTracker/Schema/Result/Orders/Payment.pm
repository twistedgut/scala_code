package Test::XTracker::Schema::Result::Orders::Payment;

use NAP::policy qw( tt test class );

BEGIN {
    extends 'NAP::Test::Class';
};

=head1 NAME

Test::XTracker::Schema::Result::Orders::Payment

=head1 DESCRIPTION

Tests various methods connected with the 'Orders::Payment' class. Most will use the
'Test::XTracker::Mock::PSP' to simulate requests to the PSP.

=cut

use Test::XTracker::Data::Order;
use Test::XTracker::Data;

use Test::XTracker::Mock::PSP;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
    :orders_payment_method_class
    :orders_internal_third_party_status
);


sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    Test::XTracker::Mock::PSP->use_all_mocked_methods();    # get the PSP Mock in a known state
}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_begin;

    # Start from a default state.
    Test::XTracker::Mock::PSP->set_payment_method('default');
    Test::XTracker::Mock::PSP->set_third_party_status('');

    my @channels = Test::XTracker::Data->get_enabled_channels->all;
    my $order_data = Test::XTracker::Data::Order->create_new_order( {
            channel => $channels[0],
    } );

    $self->{order} = $order_data->{order_object};

    $self->{payment_method}{creditcard} =
        $self->rs('Orders::PaymentMethod')->search( {
            payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__CARD,
        } )->first;
    $self->{payment_method}{thirdparty} =
        $self->rs('Orders::PaymentMethod')->search( {
            payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
        } )->first;

    $self->{internal_third_party_statuses}  = {
        map { $_->id => $_ }
            $self->rs('Orders::InternalThirdPartyStatus')->all
    };
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->schema->txn_rollback;

    # Tidy up after oursleves.
    Test::XTracker::Mock::PSP->set_payment_method('default');
    Test::XTracker::Mock::PSP->set_third_party_status('');

    $self->SUPER::teardown;
}

sub test_shutdown : Test( shutdown => no_plan ) {
    my $self = shift;
    $self->SUPER::shutdown;

    Test::XTracker::Mock::PSP->use_all_original_methods();
}


=head1 TESTS

=head2 test_get_internal_third_party_status

Tests the method 'get_internal_third_party_status' which is used to return the
Internal Third Party Status version of the Third Party Status supplied by the PSP.

=cut

sub test_get_internal_third_party_status : Tests {
    my $self    = shift;

    my $order   = $self->{order};
    $order->payments->delete;


    # create a Third Party PSP Payment Method
    my $method_rec = $self->rs('Orders::PaymentMethod')->update_or_create( {
        payment_method          => 'TestPSP',
        payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
        string_from_psp         => 'TESTPSP',
        display_name            => 'TestPSP',
    } );
    $method_rec->third_party_payment_method_status_maps->delete;

    # now map Third Party Statuses to Internal Statuses
    my @status_map;
    foreach my $internal_status ( values %{ $self->{internal_third_party_statuses} } ) {
        my $third_party_status = uc( $internal_status->status ) . '_EXTERNAL';
        $third_party_status    =~ s/ /_/g;

        push @status_map, $method_rec->create_related( 'third_party_payment_method_status_maps', {
            third_party_status  => $third_party_status,
            internal_status_id  => $internal_status->id,
        } );
    }

    # create a Payment with the new Payment Method
    my $psp_refs = Test::XTracker::Data->get_new_psp_refs();
    my $payment  = Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref           => $psp_refs->{psp_ref},
        preauth_ref       => $psp_refs->{preauth_ref},
        payment_method_id => $method_rec->id,
    } );

    # set the Mock to use the Method
    Test::XTracker::Mock::PSP->set_payment_method('TESTPSP');

    # loop round all the created records in @status_map setting the
    # Mock PSP to return an External Status and then expect the
    # mapped Internal Status to be Returned
    foreach my $status ( @status_map ) {
        note "Testing using Third Party Status: '" . $status->third_party_status . "'";

        my $expect_internal_status = $status->internal_status;

        Test::XTracker::Mock::PSP->set_third_party_status( $status->third_party_status );

        my $got_internal_status = $payment->get_internal_third_party_status();
        isa_ok( $got_internal_status, 'XTracker::Schema::Result::Orders::InternalThirdPartyStatus',
                        "'set_third_party_status' method returned an Internal Status record" );
        cmp_ok( $got_internal_status->id, '==', $expect_internal_status->id,
                        "and the Status is as Expected: '" . $expect_internal_status->status . "'" );
    }
}

=head2 test_copy_to_replacement

Test the 'copy_to_replacement' method that copies the existing 'orders.payment'
record to 'orders.replaced_payment'. Checks that this also moves any logs that
are in the following tables to their Replacement equivalents:

    orders.log_payment_preauth_cancellation
    orders.log_payment_fulfilled_change
    orders.log_payment_valid_change

=cut

sub test_copy_to_replacement : Tests {
    my $self = shift;

    my $order   = $self->{order};
    # get rid of any Payment
    $order->payments->delete;

    # create a new Payment
    my $psp_refs = Test::XTracker::Data->get_new_psp_refs();
    my $payment  = Test::XTracker::Data->create_payment_for_order( $order, $psp_refs )->discard_changes;


    note "TESTING Copying Payment without any Logs to Move";
    my $replaced_payment = $payment->copy_to_replacement_and_move_logs();
    isa_ok( $replaced_payment, 'XTracker::Schema::Result::Orders::ReplacedPayment',
                                    "'orders.replaced_payment' record created" );
    my %expected_fields = $payment->get_columns();
    # get rid of any fields that won't be in the Replaced Payment
    delete $expected_fields{ $_ }       foreach ( qw( id last_updated ) );
    my %got = $replaced_payment->get_columns();
    cmp_deeply( \%got, superhashof( \%expected_fields ), "and Replaced Payment record contains the expected data" );


    note "TESTING Copying Payment with various different Logs to Move";
    # create a different Payment
    $order->discard_changes->payments->delete;
    $psp_refs = Test::XTracker::Data->get_new_psp_refs();
    $payment  = Test::XTracker::Data->create_payment_for_order( $order, $psp_refs )->discard_changes;

    # create some 'orders.log_payment_preauth_cancellations' Logs:
    my @cancellation_logs = (
        {
            cancelled   => 0,
            preauth_ref_cancelled => $payment->preauth_ref,
            context     => 'test 1',
            message     => 'test 1 message',
            operator_id => $APPLICATION_OPERATOR_ID,
        },
        {
            cancelled   => 1,
            preauth_ref_cancelled => $payment->preauth_ref,
            context     => 'test 2',
            message     => 'test 2 message',
            operator_id => $APPLICATION_OPERATOR_ID,
        }
    );
    $payment->create_related( 'log_payment_preauth_cancellations', $_ )     foreach ( @cancellation_logs );

    # create some 'orders.log_payment_fulfilled_changes' Logs:
    my @fulfilled_logs = (
        {
            new_state         => 1,
            operator_id       => $APPLICATION_OPERATOR_ID,
            reason_for_change => 'reason 1',
        },
        {
            new_state         => 0,
            operator_id       => $APPLICATION_OPERATOR_ID,
            reason_for_change => 'reason 2',
        }
    );
    $payment->create_related( 'log_payment_fulfilled_changes', $_ )     foreach ( @fulfilled_logs );

    # create some 'orders.log_payment_valid_changes' Logs:
    my @valid_changes = (
        {
            new_state => 0,
        },
        {
            new_state => 1,
        }
    );
    $payment->create_related( 'log_payment_valid_changes', $_ )     foreach ( @valid_changes );

    $replaced_payment = $payment->copy_to_replacement_and_move_logs();
    isa_ok( $replaced_payment, 'XTracker::Schema::Result::Orders::ReplacedPayment',
                                    "'orders.replaced_payment' record created" );
    %expected_fields = $payment->get_columns();
    # get rid of any fields that won't be in the Replaced Payment
    delete $expected_fields{ $_ }       foreach ( qw( id last_updated ) );
    %got = $replaced_payment->get_columns();
    cmp_deeply( \%got, superhashof( \%expected_fields ), "and Replaced Payment record contains the expected data" );

    # check that all the logs have moved
    $self->_check_logs_have_moved( $payment, $replaced_payment, 'preauth_cancellations', \@cancellation_logs );
    $self->_check_logs_have_moved( $payment, $replaced_payment, 'fulfilled_changes', \@fulfilled_logs );
    $self->_check_logs_have_moved( $payment, $replaced_payment, 'valid_changes', \@valid_changes );
}

#----------------------------------------------------------------------------

# checks that Payment Logs have been moved when a
# payment is copied to 'orders.replaced_payment'
sub _check_logs_have_moved {
    my ( $self, $orig_payment, $replaced_payment, $log_relation, $logs_to_expect ) = @_;

    my $orig_log_relation     = "log_payment_${log_relation}";
    my $replaced_log_relation = "log_replaced_payment_${log_relation}";

    my $count = $orig_payment->search_related( $orig_log_relation )->count;
    cmp_ok( $count, '==', 0, "no '${orig_log_relation}' records found for Original Payment" );

    $count = $replaced_payment->search_related( $replaced_log_relation )->count;
    cmp_ok( $count, '==', scalar( @{ $logs_to_expect } ), "found '${replaced_log_relation}' records for Replaced Payment" );

    # now check the contents of the Logs to make sure the correct
    # data got copied, before doing that go through the $logs_to_expect
    # list and convert each value to be a 'superhashof' because fields
    # like 'ids' will not be the same
    my @expect_logs;
    foreach my $value ( @{ $logs_to_expect } ) {
        push @expect_logs, superhashof( $value );
    }

    # convert the log records into Hash Refs. so they can be compared
    my @logs = $replaced_payment->search_related( $replaced_log_relation )->all;
    my @got_logs;
    foreach my $log ( @logs ) {
        my %rec = $log->get_columns();
        push @got_logs, \%rec;
    }

    # now compare the Logs
    cmp_deeply( \@got_logs, bag( @expect_logs ), "and the Log records have the expected Data" )
                        or diag "ERROR - Log records have incorrect Data\n" .
                                "Got: " . p( @got_logs ) . "\n" .
                                "Expected: " . p( @expect_logs );

    return;
}

