#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use base 'Test::Class';

use Test::XTracker::RunCondition    export => qw( $distribution_centre );

=head1 NAME

finance_fraudrules_bulktest.t

=head1 DESCRIPTION

Tests the /Finance/FraudRules/BulkTest page.

Verifies that orders match the specified CONRAD rule set as expected
showing which orders match and which do not.

#TAGS conrad cando

=head1 TESTS

=cut

BEGIN {

    use_ok 'XTracker::Constants::FromDB', qw(
        :authorisation_level
        :order_status
    );

}

=head2 test_startup

    * Test that all modules can be loaded.
    * Prepare required objects and data:
        * Framework, Orders, Rules and Permissions.
    * Log in.

=cut

sub test_startup : Test( startup => no_plan ) {
    my $self = shift;

    use_ok 'Test::XTracker::Data';
    use_ok 'Test::XTracker::Data::FraudRule';
    use_ok 'Test::XT::Flow';
    use_ok 'XTracker::Config::Local', qw( config_var );

    # Get a framework.
    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Finance',
        ],
    );

    # Put us in the Finance department.
    Test::XTracker::Data->set_department( 'it.god', 'Finance' );

    # Log in.
    $self->{framework}->login_with_permissions( {
        perms => {
            $AUTHORISATION_LEVEL__OPERATOR => [
                'Finance/Fraud Rules',
            ]
        }
    } );

    # Create two orders, put them in a Hashref in an ArrayRef, so
    # we can have handy order numbers to interpolate into strings.
    # Like This:
    #   $self->{orders}[0]{object} <- the order object
    #   $self->{orders}[0]{number} <- the order number
    $self->{orders} = [
        map { {
            object => $_,
            number => $_->order_nr
        } } _create_orders( 2 )
    ];

    # Create one rule/conditon and disable all others.
    $self->_setup_rules;

}

=head2 test_shutdown

Delete all the data we created.

=cut

sub test_shutdown : Test( shutdown => no_plan ) {
    my $self = shift;

    note 'Deleting the two rules';
    $self->{pass_rule}->staging_conditions->delete;
    $self->{pass_rule}->delete;
    $self->{failure_rule}->staging_conditions->delete;
    $self->{failure_rule}->delete;

    note 'Re-enabling the rules';
    $_->update( { enabled => 1 } )
        foreach @{ $self->{enabled_rules} };

    note 'Deleting the two orders';
    my @orders = @{ $self->{orders} };
    foreach my $order_index ( 0 .. $#orders ) {
        $self->{orders}[ $order_index ]{object}->tenders->delete;
        $self->{orders}[ $order_index ]{object}->link_orders__shipments->delete;
        $self->{orders}[ $order_index ]{object}->delete;
    }

}

=head2 test_setup

Before each test begins, go to the /Finance/FraudRules/BulkTest page.

=cut

sub test_setup : Test( setup => no_plan ) {
    my $self = shift;

    # Go to the Bulk Test page.
    $self->{framework}->flow_mech__finance__fraud_rules__bulk_test;

}

=head2 test_no_order_numbers

Make sure the user gets an error, if they didn't provide any order
numbers.

=cut

sub test_no_order_numbers : Tests() {
    my $self = shift;

    # Test when no orders are provided, we get the expected error.
    $self->{framework}->catch_error(
        'Please enter some order numbers.',
        'Submitting no order numbers causes the correct error',
        flow_mech__finance__fraud_rules__bulk_test__test_submit => ( {
            ruleset         => 'staging',
            expected_result => $ORDER_STATUS__CREDIT_HOLD,
            orders          => '',
        } )
    );

}

=head2 test_invalid_order_number

Make sure an error and a list of invalid orders is displayed when
an invalid order number is entered.

=cut

sub test_invalid_order_number : Tests() {
    my $self = shift;

    my $framework = $self->{framework};
    my $mech = $framework->mech;

    # Test when an invalid order number is provided, we get the expected error.
    $framework->catch_error(
        'Some of the order numbers are invalid, please check and try again.',
        'Submitting invalid order numbers causes the correct error',
        flow_mech__finance__fraud_rules__bulk_test__test_submit => ( {
            ruleset         => 'staging',
            expected_result => $ORDER_STATUS__CREDIT_HOLD,
            orders          => '1',
        } )
    );

    # Check we got the right list of invalid orders.
    is_deeply(
        $mech->as_data->{invalid_order_numbers},
        [ { "Order Number" => 1, "Reason" => "Does not exist" } ],
        'We got the right list of invalid orders back'
    );

}

=head2 test_with_alpha_numeric_order_numbers

Test using Alpha Numeric Order Numbers which currently
are assigned to Jimmy Choo Orders, but only in DC1 & DC2.

=cut

sub test_with_alpha_numeric_order_numbers : Tests {
    my $self = shift;

    my ( $order1, $order2, $order3 ) = _create_orders( 3 );

    my $framework = $self->{framework};
    my $mech      = $framework->mech;

    # store the original numbers so they can be restored later
    my $original_nr1 = $order1->order_nr;
    my $original_nr2 = $order2->order_nr;
    my $original_nr3 = $order3->order_nr;

    # update the Order Numbers to be Alpha Numeric
    $order1->discard_changes->update( { order_nr => 'JCHGB00'  . $order1->order_nr } );
    $order2->discard_changes->update( { order_nr => 'JCHROW00' . $order2->order_nr } );
    $order3->discard_changes->update( { order_nr => 'JCHUS00'  . $order3->order_nr } );

    # as they are Alpha Numeric they can be back to back
    my $order_nrs = $order1->discard_changes->order_nr .
                    $order2->discard_changes->order_nr .
                    $order3->discard_changes->order_nr;

    if ( $distribution_centre ne 'DC3' ) {
        # Alpha Numeric Numbers only used in DC1 & DC2 so check they can be found
        $framework->flow_mech__finance__fraud_rules__bulk_test__test_submit( {
            ruleset         => 'staging',
            expected_result => $ORDER_STATUS__CREDIT_HOLD,
            orders          => $order_nrs,
        } );
        # no errors means the Orders were found
        $mech->no_feedback_error_ok;
    }
    else {
        # Alpha Numeric Numbers are NOT used in DC3 so check they can't be found
        $framework->catch_error(
            'Some of the order numbers are invalid, please check and try again.',
            'Submitting Alphanumeric Order Numbers causes an Error',
            flow_mech__finance__fraud_rules__bulk_test__test_submit => ( {
                ruleset         => 'staging',
                expected_result => $ORDER_STATUS__CREDIT_HOLD,
                orders          => $order_nrs,
            } )
        );
    }

    # restore Order Numbers
    $order1->discard_changes->update( { order_nr => $original_nr1 } );
    $order2->discard_changes->update( { order_nr => $original_nr2 } );
    $order3->discard_changes->update( { order_nr => $original_nr3 } );
}

=head2 test_invalid_and_valid_order_number

Make sure an error and a list of invalid orders is still displayed
when both a valid and an invalid order number is entered.

=cut

sub test_invalid_and_valid_order_number : Tests() {
    my $self = shift;

    my $framework = $self->{framework};
    my $mech = $framework->mech;

    # Test an invalid order number and a valid order number.
    $framework->catch_error(
        'Some of the order numbers are invalid, please check and try again.',
        'Submitting invalid order numbers and a valid order number causes the correct error',
        flow_mech__finance__fraud_rules__bulk_test__test_submit => ( {
            ruleset         => 'staging',
            expected_result => $ORDER_STATUS__CREDIT_HOLD,
            orders          => "1 $self->{orders}[0]{number}",
        } )
    );

    # Check we got the right list of invalid orders.
    is_deeply(
        $mech->as_data->{invalid_order_numbers},
        [ { "Order Number" => 1, "Reason" => "Does not exist" } ],
        'We got the right list of invalid orders back'
    );

}

=head2 test_valid_order_numbers_both_fail

Make sure that the correct message and a list of orders is
displayed when both fail.

=cut

sub test_valid_order_numbers_both_fail : Tests() {
    my $self = shift;

    my $framework = $self->{framework};
    my $mech = $framework->mech;

    # Update both the orders to fail the test.
    $self->_update_orders( 0, 0 );

    # Test two valid order numbers
    $framework->flow_mech__finance__fraud_rules__bulk_test__test_submit( {
        ruleset         => 'staging',
        expected_result => $ORDER_STATUS__CREDIT_HOLD,
        orders          => "$self->{orders}[0]{number} $self->{orders}[1]{number}",
    } );

    # Make sure they don't result in any errors.
    $mech->no_feedback_error_ok;

    # Make sure we only got the right messages.
    ok( exists $mech->as_data->{all_failed}, 'all_failed message is present' );
    ok( ! exists $mech->as_data->{all_passed}, 'all_passed message is not present' );
    ok( ! exists $mech->as_data->{order_passes}, 'order_passes message is not present' );
    ok( ! exists $mech->as_data->{order_failures}, 'order_failures message is not present' );

    # Make sure the message is correct.
    like(
        $mech->as_data->{all_failed},
        qr/Both Orders Failed/,
        'Both orders failed as expected'
    );

    $self->_failed_orders_ok( $self->{orders}[0]{object}, $self->{orders}[1]{object} );
    $self->_passed_orders_ok;

}

=head2 test_valid_order_numbers_one_passes_one_fails

Make sure that the correct message and a list of orders is
still displayed when one of two fail.

=cut

sub test_valid_order_numbers_one_passes_one_fails : Tests() {
    my $self = shift;

    my $framework = $self->{framework};
    my $mech = $framework->mech;

    # Update one order to fail and one to pass.
    $self->_update_orders( 0, 1 );

    # Test two valid order numbers
    $framework->flow_mech__finance__fraud_rules__bulk_test__test_submit( {
        ruleset         => 'staging',
        expected_result => $ORDER_STATUS__CREDIT_HOLD,
        orders          => "$self->{orders}[0]{number} $self->{orders}[1]{number}",
    } );

    # Make sure they don't result in any errors.
    $mech->no_feedback_error_ok;

    # Make sure we only got the right messages.
    ok( ! exists $mech->as_data->{all_failed}, 'all_failed message is not present' );
    ok( ! exists $mech->as_data->{all_passed}, 'all_passed message is not present' );
    ok( exists $mech->as_data->{order_passes}, 'order_passes message is present' );
    ok( exists $mech->as_data->{order_failures}, 'order_failures message is present' );

    # Make sure the PASS message is correct.
    like(
        $mech->as_data->{order_passes},
        qr/1 Order Passed/,
        'One of the orders passed as expected'
    );

    # Make sure the FAIL message is correct.
    like(
        $mech->as_data->{order_failures},
        qr/1 Order Failed/,
        'One of the orders failed as expected'
    );

    $self->_failed_orders_ok( $self->{orders}[0]{object} );
    $self->_passed_orders_ok( $self->{orders}[1]{object} );

}

=head2 test_valid_order_numbers_both_pass

Make sure that when everything is OK, we get the correct message 'All Orders Passed'

=cut

sub test_valid_order_numbers_both_pass : Tests() {
    my $self = shift;

    my $framework = $self->{framework};
    my $mech = $framework->mech;

    # Update both the orders to pass the test.
    $self->_update_orders( 1, 1 );

    # Test two valid order numbers
    $framework->flow_mech__finance__fraud_rules__bulk_test__test_submit( {
        ruleset         => 'staging',
        expected_result => $ORDER_STATUS__CREDIT_HOLD,
        orders          => "$self->{orders}[0]{number} $self->{orders}[1]{number}",
    } );

    # Make sure they don't result in any errors.
    $mech->no_feedback_error_ok;

    # Make sure we only got the right messages.
    ok( ! exists $mech->as_data->{all_failed}, 'all_failed message is not present' );
    ok( exists $mech->as_data->{all_passed}, 'all_passed message is present' );
    ok( ! exists $mech->as_data->{order_passes}, 'order_passes message is not present' );
    ok( ! exists $mech->as_data->{order_failures}, 'order_failures message is not present' );

    # Make sure the message is correct.
    like(
        $mech->as_data->{all_passed},
        qr/Both Orders Passed/,
        'Both orders passed as expected'
    );

    $self->_failed_orders_ok;
    $self->_passed_orders_ok( $self->{orders}[0]{object}, $self->{orders}[1]{object} );

}

Test::Class->runtests;

# ---------- PRIVATE HELPER METHODS ---------- #

# Returns $how_many order objects.
sub _create_orders {
    my ( $how_many ) = @_;

    # Default of one order.
    $how_many //= 1;
    my @orders;

    my $schema = Test::XTracker::Data->get_schema;

    # need to use local currency so exchange rates
    # don't get factored in when running the tests
    my $local_currency =
        $schema->resultset('Public::Currency')
                ->find( {
        currency => config_var('Currency', 'local_currency_code')
    } );

    foreach my $count ( 1 .. $how_many ) {

        note "Creating order $count ...";

        my ( undef, $pids ) = Test::XTracker::Data->grab_products;

        my ( $order ) = Test::XTracker::Data->create_db_order( {
            pids => $pids,
            base => {
                currency_id => $local_currency->id,
            },
        } );

        push @orders, $order;

    }

    return @orders;

}

# Disables all existing rules and creates a new one, with one condition
# for the Order Total Value, so it's the only enabled rule.
sub _setup_rules {
    my $self = shift;

    my $staging_rules = $self
        ->{framework}
        ->schema
        ->resultset('Fraud::StagingRule');

    # Cache the rules that are disabled, so we can re-enable them later.
    $self->{enabled_rules} = [ $staging_rules->search( { enabled => 1 } )->all ];

    # Disable any existing rules (for sanity).
    $staging_rules->update( { enabled => 0 } );

    # Make sure there are no rules enabled.
    cmp_ok(
        $staging_rules->search( { enabled => 1 } )->count,
        '==',
        0,
        'There are no enabled rules'
    );

    # Create a rule and a condition that will pass (expecting Credit Hold).
    $self->{pass_rule} = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Staging', {
        how_many          => 1,
        conditions_to_use => [ {
            method   => 'Order Total Value',
            operator => '>',
            value    => 100,
        } ]
    } )
    ->update( { action_order_status_id => $ORDER_STATUS__CREDIT_HOLD } );

    # Create a rule and a condition that will fail (not Credit Hold).
    $self->{failure_rule} = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Staging', {
        how_many          => 1,
        conditions_to_use => [ {
            method   => 'Order Total Value',
            operator => '<',
            value    => 50,
        } ]
    } )
    ->update( { action_order_status_id => $ORDER_STATUS__ACCEPTED } );

}

sub _update_orders {
    my ($self,  $order1, $order2 ) = @_;

    $self->_update_order( 0, $order1 );
    $self->_update_order( 1, $order2 );

}

sub _update_order {
    my ($self,  $order_index, $pass ) = @_;

    my $counter = 0;

    foreach my $shipment (  $self->{orders}[ $order_index ]{object}->shipments->all ) {

        $shipment->update( {
            shipping_charge => 0,
        } );

        $shipment->shipment_items->update( {
            unit_price => $pass ? 200 : 1,
            tax        => 0,
            duty       => 0,
        } );

        $counter++;
    }

    # update the Original Purchase Order Total
    $self->{orders}[ $order_index ]{object}->update( {
        total_value => $counter * ( $pass ? 200 : 1 ),
    } );

}

sub _failed_orders_ok { shift->_passed_failed_orders_ok( 'failure', @_ ) }
sub _passed_orders_ok { shift->_passed_failed_orders_ok( 'pass', @_ ) }

sub _passed_failed_orders_ok {
    my ($self,  $type, @orders ) = @_;

    # Check we got the right list of order failures.
    is_deeply(
        $self->{framework}->mech->as_data->{ "order_${type}_list" },
        # If no orders where given, then we should expect undef. Otherwise, explode
        # the orders into the expected structure.
        @orders ? [ map { {
            'Order Number'  => {
                url   => '/CustomerCare/OrderSearch/OrderView?order_id=' . $_->id,
                value => $_->order_nr,
            },
            'Deciding Rule' => $self->{ "${type}_rule" }->name,
            'Order Status'  => $self->{ "${type}_rule" }->action_order_status->status,
        } } @orders ] : undef,
        "$type list: We got " . ( @orders ? 'the right list of' : 'no' ) . ' orders as expected'
    );

}
