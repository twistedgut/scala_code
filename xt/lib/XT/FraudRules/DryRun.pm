package XT::FraudRules::DryRun;
use NAP::policy "tt", 'class';

=head1 NAME

XT::FraudRules::DryRun

=head1 SYNOPSIS

use XT::FraudRules::DryRun;

    my $orders = $schema
        ->resultset('Public::Orders')
        ->from_text( $some_orders );

    my $dry_run = XT::FraudRules::DryRun->new(
        orders                => $orders,
        expected_order_status => $schema->resultset(Public::OrderStatus)->first,
        rule_set              => 'staging',
    );

    $dry_run->execute;

    if ( $dry_run->has_passes ) {

        my $pass_count = $dry_run->pass_count;
        my @passes     = $dry_run->passes;

        print "Orders That Passed: $pass_count\n";

        foreach my $pass ( @passes ) {

            print ' > ' . $pass->order->order_nr . "\n";

        }

    }

    if ( $dry_run->has_failures ) {

        my $failure_count = $dry_run->failure_count;
        my @failures      = $dry_run->failures;

        print "Orders That Failed: $failure_count\n";

        foreach my $failure ( @failures ) {

            print ' > ' . $failure->order->order_nr . "\n";

        }

    }

=head1 DESCRIPTION

Takes a ResultSet of C<orders> and an C<expected_order_status>, then
runs them through C<XT::FraudRules::Engine> in test mode on a
given C<rule_set> (default is 'staging').

Orders are placed in either C<passes> (it was as expected) or
C<failures> (not as expected), depending on whether the engine
result matches the C<expected_order_status> or not.

=cut

use XT::FraudRules::Type;
use XT::FraudRules::Engine;
use XT::FraudRules::DryRun::Result;
use Moose::Util::TypeConstraints;

=head1 ATTRIBUTES

=head2 orders

Required: Yes

A ResultSet of C<Public::Orders> objects to process.

=cut

has orders => (
    is       => 'ro',
    isa      => class_type( 'XTracker::Schema::ResultSet::Public::Orders' ),
    required => 1,
);

=head2 expected_order_status

Required: Yes

The C<Public::OrderStatus> that the engine must apply to an order to
put it in the C<passes> results. Otherwise they are put in the
C<failures> results.

=cut

has 'expected_order_status' => (
    is       => 'ro',
    isa      => class_type( 'XTracker::Schema::Result::Public::OrderStatus' ),
    required => 1,
);

=head2 rule_set

Required: No
Default : staging

The rule set to test the rules on, currently either live or
staging.

=cut

has 'rule_set' => (
    is       => 'ro',
    isa      => 'XT::FraudRules::Type::RuleSet',
    required => 0,
    default  => 'staging',
);

=head2 has_passes

Returns true if any of the C<orders> passed.

=head2 pass_count

Returns the number of C<orders> that passed.

=head2 passes

Returns and ArrayRef of C<XT::FraudRules::DryRun::Result>
objects for C<orders> that passed.

=cut

# _passes
# A private attribute to store orders that have passed.

has "_passes" => (
    is       => 'ro',
    traits   => [ 'Array' ],
    handles  => {
        "has_passes" => 'count',
        "pass_count" => 'count',
        "passes"     => 'elements',
        "_add_pass"  => 'push',
    },
    isa      => 'ArrayRef[XT::FraudRules::DryRun::Result]',
    init_arg => undef,
    default  => sub { [] },
);

=head2 has_failures

Returns true if any of the C<orders> failed.

=head2 failure_count

Returns the number of C<orders> that failed.

=head2 failures

Returns and ArrayRef of C<XT::FraudRules::DryRun::Result>
objects for C<orders> that failed.

=cut

# _failures
# A private attribute to store orders that have failed.

has "_failures" => (
    is       => 'ro',
    traits   => [ 'Array' ],
    handles  => {
        "has_failures"  => 'count',
        "failure_count" => 'count',
        "failures"      => 'elements',
        "_add_failure"  => 'push',
    },
    isa      => 'ArrayRef[XT::FraudRules::DryRun::Result]',
    init_arg => undef,
    default  => sub { [] },
);

=head2 execute

Process the C<$orders> using C<XT::FraudRules::Engine>.

    my $dry_run = XT::FraudRules::DryRun->new(
        # ...
    );

    $dry_run->execute;

=cut

sub execute {
    my $self = shift;

    while ( my $order = $self->orders->next ) {
    # For each order.

        # Create a new instance of the fraud rules engine.
        my $engine = XT::FraudRules::Engine->new(
            order    => $order,
            mode     => 'test',
            rule_set => $self->rule_set,
        );

        # Execute the rules engine for this order.
        my $order_status = $engine->apply_rules;

        # Create a new result object.
        my $result = XT::FraudRules::DryRun::Result->new(
            order          => $order,
            engine_outcome => $engine->outcome,
        );

        if ( $order_status->id == $self->expected_order_status->id ) {
        # If the order_status for the order was as expected.

            # Add it to the list of passes.
            $self->_add_pass( $result );

        } else {
        # If the order_status for the order was NOT as expected.

            # Add it to the list of failures.
            $self->_add_failure( $result );

        }

    }

    return;

}

=head2 all_passed

Returns true if all the C<orders> passed.

    if ( $dry_run->all_passed ) {

        print 'All the orders passed!';

    }

=cut

sub all_passed {
    my $self = shift;

    return
        $self->has_passes &&
        ! $self->has_failures;

}

=head2 all_failed

Returns true if all the C<orders> failed.

    if ( $dry_run->all_failed ) {

        print 'All the orders failed!';

    }

=cut

sub all_failed {
    my $self = shift;

    return
        ! $self->has_passes &&
        $self->has_failures;

}

=head2 has_passes_and_failures

Returns true if some of the C<orders> passed and some failed.

    if ( $dry_run->has_passes_and_failures ) {

        print 'The orders had both passes and failures!';

    }

=cut

sub has_passes_and_failures {
    my $self = shift;

    return
        $self->has_passes &&
        $self->has_failures;

}

=head2 all_passed_as_string

Returns the number of passes stringified to describe how many
passed. This will be one of the following:

    * No Orders Passed
    * The Order Passed
    * Both Orders Passed
    * All N Orders Passed

    print $dry_run->all_passed_as_string;

=cut

sub all_passed_as_string {
    my $self = shift;

    # Cannot be true if we have failures.
    return 'Not All Orders Passed' if $self->has_failures;

    return _stringify_all_order_count( $self->pass_count, 'Passed' );

}

=head2 all_failed_as_string

Returns the number of failures stringified to describe how many
failed. This will be one of the following:

    * No Orders Failed
    * The Order Failed
    * Both Orders Failed
    * All N Orders Failed

    print $dry_run->all_failed_as_string;

=cut

sub all_failed_as_string {
    my $self = shift;

    # Cannot be true if we have passes.
    return 'Not All Orders Failed' if $self->has_passes;

    return _stringify_all_order_count( $self->failure_count, 'Failed' );

}

=head2 pass_count_as_string

Returns a stringified count of orders that passed.

For example: "No Orders Passed", "1 Order Passed",
"2 Orders Passed", ...

    print $dry_run->pass_count_as_string;

=cut

sub pass_count_as_string {
    my $self = shift;

    return _pluralise_passed_failed( $self->pass_count, 'Passed' );

}

=head2 failure_count_as_string

Returns a stringified count of orders that failed.

For example: "No Orders Failed", "1 Order Failed",
"2 Orders Failed", ...

    print $dry_run->failure_count_as_string;

=cut

sub failure_count_as_string {
    my $self = shift;

    return _pluralise_passed_failed( $self->failure_count, 'Failed' );

}

# _stringify_all_order_count( $count, $passed_failed )
#
# Returns the stringified version of an order count for a
# specific type.
#
#   my $passes   = _stringify_all_order_count( $count, 'Passed' );
#   my $failures = _stringify_all_order_count( $count, 'Failed' );
#
# Returns one of the following:
#
#   * The Order $passed_failed
#   * Both Orders $passed_failed
#   * All $count Orders $passed_failed

sub _stringify_all_order_count {
    my ( $count, $passed_failed ) = @_;

    SMARTMATCH: {
        use experimental 'smartmatch';
        given ( $count ) {
            when    ( 0 ) { return "No Orders $passed_failed"         }
            when    ( 1 ) { return "The Order $passed_failed"         }
            when    ( 2 ) { return "Both Orders $passed_failed"       }
            default       { return "All $count Orders $passed_failed" }
        }
    }
}

# _pluralise_passed_failed
#
# Returns a pluralised count of passed/failed orders.

sub _pluralise_passed_failed {
    my ( $count, $passed_failed ) = @_;

    return
        ( $count || 'No' ) .
        " Order" . ( $count == 1 ? "" : "s" ) .
        " $passed_failed";

}

1;
