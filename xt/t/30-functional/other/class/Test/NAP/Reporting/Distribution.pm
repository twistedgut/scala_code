package Test::NAP::Reporting::Distribution;

use NAP::policy qw/tt test/;
use FindBin::libs;

use Test::XT::Flow;

use XTracker::Constants ':application';
use XTracker::Constants::FromDB qw/
    :authorisation_level
    :delivery_action
/;

use parent 'NAP::Test::Class';

=head1 NAME

Test::NAP::Reporting::Distribution

=head1 TESTS

=cut

sub startup : Test(startup) {
    my $self = shift;

    $self->SUPER::startup;

    $self->{flow} = Test::XT::Flow->new_with_traits(
        traits => [qw/
            Test::XT::Flow::Mech::Reporting
        /],
    );
}

=head2 test_inbound_by_action_basic

A few basic tests which pretty much just check when we error and that we don't
500 in some common use cases. We go to Reporting->Distribution Reports->By
Action and perform the following tests:

=over

=item search without start date, expect an error

=item search without end date, expect an error

=item search without any delivery actions, expect an error

=item search with an invalid date ('foo'), expect an error

=item search with a valid date followed by an invalid string ('YYYY-MM-DDfoo), expect an error

=item search a start date, end date, and delivery action, expect a success

=item search with the same three above fields as well as operator_id and operator_name, expect a success

=item search with an operator_id that doesn't match the name, expect an error

=item search passing an operator_id but not an operator_name, expect a success

=back

Note that these are basic interface tests, we don't actually check that the
returned results are correct

=cut

sub test_inbound_by_action_basic : Tests {
    my $self = shift;

    my $flow = $self->{flow};

    $flow->login_with_permissions({
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Reporting/Distribution Reports',
            ],
        },
    });

    $flow->flow_mech__reporting__inbound_by_action;
    my $default_params = {
        start_date         => '2014-10-14',
        end_date           => '2014-10-15',
        delivery_action_id => $DELIVERY_ACTION__CREATE,
    };
    for (
        [ 'no start date', 0, { start_date => q{} } ],
        [ 'no end date', 0, { end_date => q{} } ],
        # Strictly speaking this won't be passed at all as delivery_action_id
        # is a checkbox, but this should do for testing
        [ 'no delivery action', 0, { delivery_action_id => [] } ],
        [ 'invalid date', 0, { start_date => 'foo' } ],
        [ 'valid date with invalid suffixed string', 0,
            { start_date => $default_params->{start_date} . 'foo' }
        ],
        [ 'valid request', 1, {} ],
        [ 'valid request with operator', 1, {
            operator_id   => $APPLICATION_OPERATOR_ID,
            operator_name => 'Application',
        } ],
        [ 'operator id/name mismatch', 0, {
            operator_id   => $APPLICATION_OPERATOR_ID,
            operator_name => 'Foo',
        } ],
        # I've written a blurb in the controller as to why we need this special
        # case, but it basically has to do with the yui autocomplete not
        # removing the operator_id if the user selects an operator and the
        # deletes it. What we do is ignore the operator_id we pass unless we
        # also pass an operator name
        [ 'trailing operator_id due to user having typed something and deleted it', 1, {
            operator_id   => $APPLICATION_OPERATOR_ID,
            operator_name => q{},
        } ],
    ) {
        my ( $test_name, $should_pass, $test_params ) = @$_;
        subtest $test_name => sub {
            my $params = {%$default_params, %$test_params};
            p( $params );
            if ( $should_pass ) {
                ok( $flow->flow_mech__reporting__inbound_by_action_submit($params),
                    'should pass' );
            }
            else {
                $flow->catch_error(
                    qr{.}, # Just test that we error
                    "should die",
                    flow_mech__reporting__inbound_by_action_submit => $params,
                );
            }
        };
    }
}
