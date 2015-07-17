package XTracker::Order::Finance::FraudRules::Test;

=head1 XTracker::Order::Finance::FraudRules::Test

Runs the Fraud Rules against a single order, selecting either the Live Rules
or the Staging Rules as requested in the rule_set parameter, and prints out
the results.

Parameters:

order_id : The id of the order
rule_set : Either Live or Staging

Prints to XT web interface:

{
    status => $OUTCOME_STATUS_ID,
    flags => $ARRAY_OF_FLAG_IDS,
    rules => $ARRAY_OF_RULES_RUN_AGAINST_ORDER,
    decisioning_rule => $ID_OF_RULE_THAT_DECIDED_OUTCOME,
    textualisation => $ARRAY_OF_TEXTUALISED_RULES_RUN
}

=cut

use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Utilities qw( :string );
use XTracker::Error;
use XTracker::Logfile qw( xt_logger );
use XTracker::Constants::FromDB qw(
    :department
);

use XT::FraudRules::Engine;

use XT::Cache::Function         qw( :stop );


sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $order_id = trim($handler->{param_of}{order_id});
    my $rule_set = trim($handler->{param_of}{rule_set});

    unless ( $order_id ) {
        xt_logger->warn(__PACKAGE__.' called without order id');
        return $handler->redirect_to('/');
    }

    my $order = $handler->schema->resultset('Public::Orders')->find( $order_id );

    unless ($order && $order->isa('XTracker::Schema::Result::Public::Orders')) {
        xt_logger->warn(__PACKAGE__.' called with an invalid order id');
        xt_error('Fraud Rules Test called for non existent order id');
        return $handler->redirect_to('/');
    }

    $handler->{data}{order_nr} = $order->order_nr;
    $handler->{data}{ruleset} = ucfirst($rule_set);

    # XTracker Template Boilerplate
    # Set the template_type to blank to prevent headers, menus, etc appearing
    $handler->{data}{template_type} = 'blank';
    $handler->{data}{content} = 'ordertracker/finance/fraudrules/test_result.tt';

    $handler->{data}{original_outcome} =
        $order->order_status_logs->first
        ? $order->search_related('order_status_logs', {}, {
                order_by => { -asc => 'id' },
            } )->first->status->status
        : 'UNKNOWN';

    my $result = _call_rules_engine( {
        order => $order,
        rule_set => $rule_set,
        handler => $handler,
    } );

    # clear the Cache so that stuff like the Fraud Hotlist
    # doesn't persist, this is in lieu of Cache Expiration
    stop_all_caching();

    $handler->{data}{result} = $result;

    return $handler->process_template();
}

sub _call_rules_engine {
    my ( $args ) = @_;

    my $order = $args->{order};

    return unless ( $order &&
        $order->isa('XTracker::Schema::Result::Public::Orders') );

    my $rules_engine = XT::FraudRules::Engine->new( {
        order       => $order,
        mode        => 'test',
        rule_set    => $args->{rule_set},
    } );

    eval { $rules_engine->apply_finance_flags(); };
    if ( my $error = $@ ) {
        xt_logger->warn('Unable to apply Fraud Rules finance flags for order id: '.$order->id);
        xt_error('An error occured calling the Fraud Rules system');
        return $args->{handler}->redirect_to('/');
    }

    my $status;
    eval { $status = $rules_engine->apply_rules(); };
    if ( my $error = $@ ) {
        xt_logger->warn('Unable to apply Fraud Rules for order id: '.$order->id." $error");
        xt_error('An error occured calling the Fraud Rules system');
        return $args->{handler}->redirect_to('/');
    }

    my $outcome = $rules_engine->outcome;

    my @flags = map { $_->icon_name } ( $outcome->flags_assigned_rs->by_description->all );

    return {
        status => $status->status,
        flags => \@flags,
        textualisation => $outcome->textualisation,
    };
}
