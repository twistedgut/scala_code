package XTracker::Schema::ResultSet::Public::BulkOrderActionLog;

use NAP::policy "tt";

use base 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB     qw( :bulk_order_action );

sub get_logs_for_credithold_actions {
    my $self = shift;

    my @results = $self->search({
        action_id => {
            'IN' => [$BULK_ORDER_ACTION__CREDIT_HOLD_TO_ACCEPT,
                     $BULK_ORDER_ACTION__ACCEPT_TO_CREDIT_HOLD]
        },
        date => {'>=' => \"NOW() - INTERVAL '28 DAYS'"}
    },{
        order_by => {-desc => 'date'}
    });

    my %orders;

    foreach my $log (@results) {
        if ($log->order_status_logs->count > 0) {
            $orders{$log->channel->name} //= [];
            push(@{$orders{$log->channel->name}}, $log);
        }
    }

    return \%orders;
}
