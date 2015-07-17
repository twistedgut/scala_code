package Test::XT::FraudRules::DryRun;

use NAP::policy "tt", qw(
    test
    class
);

BEGIN {

    extends 'NAP::Test::Class';

    with qw(
        Test::Role::WithSchema
        Test::Role::DBSamples
    );

    use_ok 'XTracker::Constants::FromDB', qw(
        :order_status
    );
    use_ok 'XTracker::Config::Local', qw(
        config_var
    );

};

=head1 NAME

Test::XT::FraudRules::DryRun

=head2 DESCRIPTION

Tests the FraudRules::DryRun object behaves as expected.

=head1 TESTS

=head2 startup

 * Checks all the required modules can be used OK.
 * Begins a transaction.
 * Creates test data (rule and orders).

=cut

sub test_startup : Test( startup => 6 ) {
    my $self = shift;

    $self->SUPER::startup;

    use_ok 'Test::XTracker::Data::FraudRule';
    use_ok 'XT::FraudRules::DryRun';

    # Start the transaction.
    $self->schema->txn_begin;

    # Disable any existing rules.
    $self->rs('Fraud::StagingRule')
        ->update( { enabled => 0 } );

    # Create a rule and a condition.
    $self->{main_rule} = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Staging', {
        how_many          => 1,
        conditions_to_use => [ {
            method   => 'Order Total Value',
            operator => '>',
            value    => 100,
        } ]
    } )
    ->update( { action_order_status_id => $ORDER_STATUS__CREDIT_HOLD } );

    # Create a DEFAULT rule and a condition.
    $self->{default_rule} = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Staging', {
        how_many          => 1,
        conditions_to_use => [ {
            method   => 'Order Total Value',
            operator => '<',
            value    => 50,
        } ]
    } )
    ->update( { action_order_status_id => $ORDER_STATUS__ACCEPTED } );

    # Parameters to pass to both orders.
    my @order_arguments = (
        channel => $self->{main_rule}->channel,
    );

    # Create two orders.
    $self->{order1} = $self->test_data->new_order( @order_arguments )->{order_object};
    $self->{order2} = $self->test_data->new_order( @order_arguments )->{order_object};

    # get the Orders in the Local Currency
    my $currency    = $self->rs('Public::Currency')
                            ->find_by_name( config_var( 'Currency', 'local_currency_code' ) );
    $self->{order1}->update( { currency_id => $currency->id } );
    $self->{order2}->update( { currency_id => $currency->id } );

    # Get a ResultSet with just the created orders.
    $self->{orders} = $self->rs('Public::Orders')->search( {
        id => [
            $self->{order1}->id,
            $self->{order2}->id,
        ]
    } );

}

=head2 shutdown

Rolls back the database transaction.

=cut

sub test_shutdown : Test( shutdown => 0 ) {
    my $self = shift;

    note 'Rolling back the DB transaction';
    $self->schema->txn_rollback;

}

=head2 test_all_accepted

Make sure that if both orders pass the rule, they are both
in the list of passes.

=cut

sub test_all_accepted : Tests() {
    my $self = shift;

    # Prepare orders and instantiate new dry run object.
    my $dry_run = $self->_prepare_test( 1, 1 );

    # Check the passed orders.
    ok( $dry_run->has_passes, 'has_passes returns true' );
    is( $dry_run->pass_count, 2, 'pass_count returns 2' );
    ok( $dry_run->all_passed, 'all_passed returns true' );
    cmp_ok( $dry_run->all_passed_as_string,  'eq', 'Both Orders Passed', 'all_passed_as_string = "Both Orders Passed"' );
    cmp_ok( $dry_run->pass_count_as_string, 'eq', '2 Orders Passed', 'pass_count_as_string = "2 Orders Passed"' );
    _pass_fail_ok( $dry_run, 'passes', [ $self->{order1}, $self->{order2} ] );

    # Check the failed orders.
    ok( ! $dry_run->has_failures, 'has_failures returns false' );
    is( $dry_run->failure_count, 0, 'failure_count returns 0' );
    ok( ! $dry_run->all_failed, 'all_failed returns false' );
    cmp_ok( $dry_run->all_failed_as_string, 'eq', 'Not All Orders Failed', 'all_failed_as_string = "Not All Orders Failed"' );
    cmp_ok( $dry_run->failure_count_as_string, 'eq', 'No Orders Failed', 'failure_count_as_string = "No Orders Failed"' );

    # Check combined method.
    ok( ! $dry_run->has_passes_and_failures, 'has_passes_and_failures returns false' );

}

=head2 test_some_accepted

Make sure that if one of the orders passes the rule, there
is one order in each list of results.

=cut

sub test_some_accepted : Tests() {
    my $self = shift;

    # Prepare orders and instantiate new dry run object.
    my $dry_run = $self->_prepare_test( 1, 0 );

    # Check the passed orders.
    ok( $dry_run->has_passes, 'has_passes returns true' );
    is( $dry_run->pass_count, 1, 'pass_count returns 1' );
    ok( ! $dry_run->all_passed, 'all_passed returns false' );
    cmp_ok( $dry_run->all_passed_as_string,  'eq', 'Not All Orders Passed', 'all_passed_as_string = "Not All Orders Passed"' );
    cmp_ok( $dry_run->pass_count_as_string, 'eq', '1 Order Passed', 'pass_count_as_string = "1 Order Passed"' );
    _pass_fail_ok( $dry_run, 'passes', [ $self->{order1} ] );

    # Check the failed orders.
    ok( $dry_run->has_failures, 'has_failures returns true' );
    is( $dry_run->failure_count, 1, 'failure_count returns 1' );
    ok( ! $dry_run->all_failed, 'all_failed returns false' );
    cmp_ok( $dry_run->all_failed_as_string, 'eq', 'Not All Orders Failed', 'all_failed_as_string = "Not All Orders Failed"' );
    cmp_ok( $dry_run->failure_count_as_string, 'eq', '1 Order Failed', 'failure_count_as_string = "1 Order Failed"' );
    _pass_fail_ok( $dry_run, 'failures', [ $self->{order2} ] );

    # Check combined method.
    ok( $dry_run->has_passes_and_failures, 'has_passes_and_failures returns true' );

}

=head2 test_none_accepted

Make sure that if both orders fail the rule, they are both
in the list of failures.

=cut

sub test_none_accepted : Tests() {
    my $self = shift;

    # Prepare orders and instantiate new dry run object.
    my $dry_run = $self->_prepare_test( 0, 0 );

    # Check the passed orders.
    ok( ! $dry_run->has_passes, 'has_passes returns false' );
    is( $dry_run->pass_count, 0, 'pass_count returns 0' );
    ok( ! $dry_run->all_passed, 'all_passed returns false' );
    cmp_ok( $dry_run->all_passed_as_string,  'eq', 'Not All Orders Passed', 'all_passed_as_string = "Not All Orders Passed"' );
    cmp_ok( $dry_run->pass_count_as_string, 'eq', 'No Orders Passed', 'pass_count_as_string = "No Orders Passed"' );

    # Check the failed orders.
    ok( $dry_run->has_failures, 'has_failures returns true' );
    is( $dry_run->failure_count, 2, 'failure_count returns 2' );
    ok( $dry_run->all_failed, 'all_failed returns true' );
    cmp_ok( $dry_run->all_failed_as_string, 'eq', 'Both Orders Failed', 'all_failed_as_string = "Both Orders Failed"' );
    cmp_ok( $dry_run->failure_count_as_string, 'eq', '2 Orders Failed', 'failure_count_as_string = "2 Orders Failed"' );
    _pass_fail_ok( $dry_run, 'failures', [ $self->{order1}, $self->{order2} ] );

    # Check combined method.
    ok( ! $dry_run->has_passes_and_failures, 'has_passes_and_failures returns false' );

}

# _prepare_test
#
#  * Set the orders to pass/fail.
#  * Create a new XT::FraudRules::DryRun instance and execute it.
#  * Check the returned result is as expected.

sub _prepare_test {
    my ($self,  $order1_pass, $order2_pass ) = @_;

    my $value1  = ( $order1_pass ? 200 : 1 );
    my $value2  = ( $order2_pass ? 200 : 1 );

    # Set the order values to pass/fail the condition.
    $self->_adjust_order_value( $self->{order1}, $value1 );
    $self->_adjust_order_value( $self->{order2}, $value2 );

    # Create and return a new instance.
    my $dry_run = new_ok( 'XT::FraudRules::DryRun' => [
        # Make sure we reset the cursor, as we're using it several times.
        orders                => $self->{orders}->reset,
        expected_order_status => $self->{main_rule}->action_order_status,
        rule_set              => 'staging',
    ] );

    # Execute and return the dry run.
    $dry_run->execute;

    # Make sure all the passes/failures are the correct type and have the
    # right attributes.
    isa_ok( $_, 'XT::FraudRules::DryRun::Result' ) &&
    can_ok( $_, 'order' ) &&
    can_ok( $_, 'engine_outcome' )
        foreach (
            $dry_run->passes,
            $dry_run->failures
        );

    return $dry_run;

}

# _pass_fail_ok
#
#  * Check we have the expected orders in the list of passes/failures
#    from the $dry_run object.

sub _pass_fail_ok {
    my ( $dry_run, $passes_failures, $expected_orders ) = @_;

    foreach my $order ( @$expected_orders ) {
    # With each expected order.

        # Make sure it's in the appropriate list of results.
        my $found = grep
            { $_->order->id == $order->id }
            $dry_run->$passes_failures;

        ok( $found, 'Found order ID ' . $order->id . " in list of $passes_failures" );

    }

}

# adjust an Order's Value
sub _adjust_order_value {
    my ( $self, $order, $value )    = @_;

    $order->get_standard_class_shipment
            ->shipment_items
                ->update( {
        unit_price => $value,
        tax => 0,
        duty => 0
    } );

    # update the original Purchase Price on the Order record as well
    my $num_items   = $order->get_standard_class_shipment
                                ->shipment_items->count;
    $order->update( {
        total_value => $num_items * $value,
    } );

    return;
}

