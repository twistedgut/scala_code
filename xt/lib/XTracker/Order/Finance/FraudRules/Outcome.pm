package XTracker::Order::Finance::FraudRules::Outcome;

=head1 XTracker::Order::Finance::FraudRules::Outcome

Returns the outcome of the Fraud Rules for a given order, specified by the
order_id parameter, at the time the order was imported.

If the Fraud Rules engine was not running at the time the order was imported
returns a notice to indicate that.

Prints to XT web interface:

{
    status => $OUTCOME_STATUS_ID,
    flags => $ARRAY_OF_FLAG_IDS,
    rules => $ARRAY_OF_RULES_RUN_AGAINST_ORDER,
    decisioning_rule => $ID_OF_RULE_THAT_DECIDED_OUTCOME,
    textualisation => $ARRAY_OF_TEXTUALISED_RULES_RUN
}

or

{
    not_running => 1
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

use JSON;

use XT::FraudRules::Engine;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $order_id = trim($handler->{param_of}{order_id});

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

    my $outcome = $order->orders_rule_outcome;

    # XTracker Template Boilerplate
    # Set the template_type to blank to prevent headers, menus, etc appearing
    $handler->{data}{template_type} = 'blank';
    $handler->{data}{content} = 'ordertracker/finance/fraudrules/outcome.tt';

    $handler->{data}{order_nr} = $order->order_nr;

    if ( ! $outcome ) {
        $handler->{data}{not_run} = 1;
    }
    else {
        # Get the flags based upon the Outcome flag ids
        my $flag_rs = $handler->schema->resultset('Public::Flag')->search( {
            id => { 'IN' => [ split(/\,/, $outcome->finance_flag_ids) ] // [ -1 ] },
        } );

        $handler->{data}{result} = {
            fraud_rules_order_status => $outcome->archived_rule_id ?
                $outcome->archived_rule->action_order_status->status
                : 'UNKNOWN',
            outcome_status => $outcome->rule_outcome_status->status,
            flags => [ map { $_->icon_name } ($flag_rs->by_description->all) ],
            textualisation => decode_json($outcome->textualisation),
            order_status => $order->order_status_logs->first ?
                $order->search_related('order_status_logs', {}, {
                    order_by => { -asc => 'id' }, } )->first->status->status
                : 'UNKNOWN',
        };
    }

    return $handler->process_template();
}

1;
