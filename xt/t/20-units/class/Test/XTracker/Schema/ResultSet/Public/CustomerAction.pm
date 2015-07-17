package Test::XTracker::Schema::ResultSet::Public::CustomerAction;

use NAP::policy "tt", qw/test class/;
use FindBin::libs;

BEGIN {
    extends 'NAP::Test::Class';
    with qw(
        Test::Role::WithSchema
    );
};

use Test::XTracker::Data;
use XTracker::Constants::FromDB qw(
    :customer_action_type
);
use XTracker::Constants qw(
    $APPLICATION_OPERATOR_ID
);

=head1 NAME

Test::XTracker::Schema::ResultSet::Public::CustomerAction

=head1 DESCRIPTION

Teswt all the methods in:
    Test::XTracker::Schema::ResultSet::Public::CustomerAction

=cut

sub test_setup : Test( setup => 0 ) {
    my $self = shift;

    note 'Starting the transaction';
    $self->schema->txn_begin;

}

sub test_teardown : Test( teardown => 0 ) {
    my $self = shift;

    note 'Rolling back the transaction';
    $self->schema->txn_rollback;

}

=head1 TESTS

=head2 test_get_new_high_values

Make sure the method returns all records as expected.

=cut

sub test_get_new_high_values : Tests {
    my $self = shift;

    my $customer = Test::XTracker::Data->find_customer( {
        channel_id => Test::XTracker::Data->get_local_channel->id,
    } );

    isa_ok( $customer, 'XTracker::Schema::Result::Public::Customer' );

    # Make sure the table is empty for this customer.
    $customer->customer_actions->delete;

    # Make sure it's now empty.
    cmp_ok( $customer->customer_actions->count, '==', 0, 'The customer_action table is empty before we start' );

    # Make sure the method returns undef for an empty resultset.
    ok(
        ! defined $customer->customer_actions->get_last_new_high_value,
        'get_last_new_high_value is undefined when there are no customer actions'
    );

    # Get some static dates to use.
    my @dates;
    $dates[1] = DateTime->now->subtract( days => 1 ); # Yesterday.
    $dates[2] = $dates[1];                            # Yesterday (identical).
    $dates[3] = $dates[1]->subtract( days => 2 );     # The day before yesterday.

    # Create a bunch of records.
    $customer->customer_actions->create( {
        operator_id             => $APPLICATION_OPERATOR_ID,
        customer_action_type_id => $PUBLIC_CUSTOMER_ACTION_TYPE__NEW_HIGH_VALUE,
        date_created            => $dates[$_],
    } ) foreach 1..3;

    # Make sure they where created OK.
    cmp_ok( $customer->customer_actions->count, '==', 3, 'The customer_action table now has three records' );

    foreach my $row ( $customer->customer_actions->get_new_high_values->all ) {
    # Go through each row returned by get_new_high_values.

        # .. and compare them with what we expect.
        cmp_deeply( { $row->get_columns }, superhashof( {
            customer_id             => $customer->id,
            operator_id             => $APPLICATION_OPERATOR_ID,
            customer_action_type_id => $PUBLIC_CUSTOMER_ACTION_TYPE__NEW_HIGH_VALUE,
        } ), 'The customer_action row (id=' . $row->id . ') is as expected' );

    }

    # We'll also test the get_last_new_high_value method here, as it makes no sense to
    # repeat all the code in this test, when we already have everything we need.

    # Get the record and make sure it's the correct object.
    my $last_new_high_value = $customer->customer_actions->get_last_new_high_value;
    isa_ok( $last_new_high_value, 'XTracker::Schema::Result::Public::CustomerAction', 'get_last_new_high_value' );

    # Check the date.
    cmp_ok(
        $last_new_high_value->date_created,
        '==',
        $dates[1],
        'get_last_new_high_value returns the correct date'
    );

    # Check the ID (for two identical dates).
    cmp_ok(
        $last_new_high_value->id,
        '==',
        $customer->customer_actions->get_column( 'id' )->max,
        'get_last_new_high_value returns the correct record'
    );

}

=head2 test_add_customer_new_high_value

Make sure the method adds a single new record to the customer_action table
for the customer, of the type 'New High Value'.

=cut

sub test_add_customer_new_high_value : Tests {
    my $self = shift;

    my $customer = Test::XTracker::Data->find_customer( {
        channel_id => Test::XTracker::Data->get_local_channel->id,
    } );

    isa_ok( $customer, 'XTracker::Schema::Result::Public::Customer' );

    # Make sure the table is empty for this customer.
    $customer->customer_actions->delete;

    # Make sure it's now empty.
    cmp_ok( $customer->customer_actions->count, '==', 0, 'The customer_action table is empty before we start' );

    $customer->customer_actions->add_customer_new_high_value( {
        operator_id             => $APPLICATION_OPERATOR_ID,
        customer_action_type_id => $PUBLIC_CUSTOMER_ACTION_TYPE__NEW_HIGH_VALUE,
    } );

    # Make sure they where created OK.
    cmp_ok( $customer->customer_actions->count, '==', 1, 'The customer_action table has one record' );

    # .. and compare them with what we expect.
    cmp_deeply( { $customer->customer_actions->first->get_columns }, superhashof( {
        customer_id             => $customer->id,
        operator_id             => $APPLICATION_OPERATOR_ID,
        customer_action_type_id => $PUBLIC_CUSTOMER_ACTION_TYPE__NEW_HIGH_VALUE,
    } ), 'The customer_action record is as expected' );

}

1;

