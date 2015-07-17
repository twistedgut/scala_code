package Test::XTracker::Database::Customer;
use NAP::policy "tt", qw(
    test
);

use parent 'NAP::Test::Class';

use Test::Exception;

=head1 NAME

Test::XTracker::Database::Customer

=head1 DESCRIPTION

This is the test class for XTracker::Database::Customer

=head1 TESTS

=head2 startup()

Load required modules, start a database transaction and
create a new customer object to work with.

=cut

sub test_startup : Test( startup => 4 ) {
    my $self = shift;

    use_ok( 'Test::XTracker::Data' );
    use_ok( 'XTracker::Database::Customer' );

    # Get the schema.
    $self->{schema} = Test::XTracker::Data->get_schema;
    isa_ok( $self->{schema}, 'XTracker::Schema' );

    # Start a transaction, so we can roll it back.
    $self->{schema}->txn_begin;

    # Create a new customer.
    my $customer_id = Test::XTracker::Data->create_test_customer(
        channel_id => Test::XTracker::Data->any_channel->id,
    );

    # Get a schema object for it.
    $self->{customer} = $self->{schema}
        ->resultset('Public::Customer')
        ->find( $customer_id );

    isa_ok( $self->{customer}, 'XTracker::Schema::Result::Public::Customer' );

}

=head2 shutdown()

Tidy up after ourselves by rolling back the transaction.

=cut

sub test_shutdown : Test( shutdown ) {
    my $self = shift;

    $self->{schema}->txn_rollback;

}

=head2 test_all_methods_exist

Make sure all the method names we expect the class to provide actually exist,
we currently check for the following:

    * add_customer_flag
    * check_customer
    * check_or_create_customer
    * create_customer
    * delete_customer_flag
    * get_customer_by_email
    * get_customer_categories
    * get_customer_ddu_authorised
    * get_customer_flag
    * get_customer_from_pws
    * get_customer_from_pws_by_email
    * get_customer_info
    * get_customer_notes
    * get_customer_value
    * get_cv_order_count
    * get_cv_return_rate
    * get_cv_spend
    * get_order_address_customer_name
    * match_customer
    * search_customers
    * set_customer_category
    * set_customer_credit_check
    * set_customer_ddu_authorised
    * set_marketing_contact_date
    * update_customer

=cut

sub test_all_methods_exist : Tests {
    my $self = shift;

    my @methods = qw(
        add_customer_flag
        check_customer
        check_or_create_customer
        create_customer
        delete_customer_flag
        get_customer_by_email
        get_customer_categories
        get_customer_ddu_authorised
        get_customer_flag
        get_customer_from_pws
        get_customer_from_pws_by_email
        get_customer_info
        get_customer_notes
        get_customer_value
        get_cv_order_count
        get_cv_return_rate
        get_cv_spend
        get_order_address_customer_name
        match_customer
        search_customers
        set_customer_category
        set_customer_credit_check
        set_customer_ddu_authorised
        set_marketing_contact_date
        update_customer
    );

    can_ok( 'XTracker::Database::Customer', $_ )
        foreach @methods;

}

=head2 test_get_order_address_customer_name()

Test the get_order_address_customer_name method.

It accepts three parameters, a Public::OrderAddress object,
optional Public::Customer object and an optional flag to
turn off fixing the first name.

We create a new order in this test.

=cut

sub test_get_order_address_customer_name : Tests() {
    my $self = shift;

    my $order_address = _create_order( $self->{customer}->channel_id )->order_address;
    my $customer      = $self->{customer};

    # No parameters provided.
    throws_ok(
        sub{ get_order_address_customer_name() },
        qr/Order Address required, but not provided/,
        'Method dies as expected for missing parameters'
    );

    # First parameter not an OrderAddress object.
    throws_ok(
        sub{ get_order_address_customer_name( $customer ) },
        qr/Order Address required, but not provided/,
        'Method dies as expected when order_address is not a Public::OrderAddress object'
    );

    # Second parameter not a Customer object.
    throws_ok(
        sub{ get_order_address_customer_name( $order_address, $order_address ) },
        qr/Customer provided, but not actually a Customer object/,
        'Method dies as expected when customer is not a Public::Customer object'
    );

    # Both parameters are valid.
    lives_ok(
        sub{ get_order_address_customer_name( $order_address, $customer ) },
        'Method lives when passed correct parameter types'
    );

    # Update the order address to contain known values.
    $order_address->update( {
        first_name => 'test',
        last_name  => 'name',
    } );

    # Update the customer details to contain known values.
    $customer->update( {
        title      => 'customer_title',
        first_name => 'test',
        last_name  => 'name',
    } );

    my %tests = (
        'just order_address' => {
            parameters => [ $order_address ],
            expected   => {
                title      => undef,
                first_name => 'Test',
                last_name  => 'name',
            },
        },
        'order_address and customer' => {
            parameters => [ $order_address, $customer ],
            expected   => {
                title      => 'customer_title',
                first_name => 'Test',
                last_name  => 'name',
            },
        },
        'just order_address with no fix' => {
            parameters => [ $order_address, undef, 0 ],
            expected   => {
                title      => undef,
                first_name => 'test',
                last_name  => 'name',
            },
        },
        'order_address and customer with no fix' => {
            parameters => [ $order_address, $customer, 0 ],
            expected   => {
                title      => 'customer_title',
                first_name => 'test',
                last_name  => 'name',
            },
        },
    );

    while ( my ( $name, $test ) = each %tests ) {
    # Do each test.

        my $result = get_order_address_customer_name( @{ $test->{parameters} });

        # Make sure we got what we expected.
        is_deeply( $result, $test->{expected}, "Results are as expected for $name" );

    }

}

=head1 METHODS

=head2 _create_order()

Private helper method to create a new order on a specific channel.

=cut

sub _create_order {
    my ( $channel_id ) = @_;

    # Get a product for a new order.
    my ( $channel, $pids ) = Test::XTracker::Data->grab_products( {
        how_many   => 1,
        channel_id => $channel_id,
    } );

    isa_ok( $channel, 'XTracker::Schema::Result::Public::Channel' );
    isa_ok( $pids, 'ARRAY' );

    # Create the test order.
    my ( $order ) = Test::XTracker::Data->create_db_order( {
        pids       => $pids,
        channel_id => $channel->id,
    } );

    isa_ok( $order, 'XTracker::Schema::Result::Public::Orders' );

    return $order;

}
