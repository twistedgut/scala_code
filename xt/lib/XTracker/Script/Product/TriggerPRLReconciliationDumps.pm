package XTracker::Script::Product::TriggerPRLReconciliationDumps;

use Moose;
use XTracker::Config::Local 'config_var';
use XT::JQ::DC;
use Try::Tiny;
extends 'XTracker::Script';
with 'XTracker::Script::Feature::Schema',
    'XTracker::Role::WithAMQMessageFactory';

use DateTime;
use XT::Domain::PRLs;

use XTracker::Logfile 'xt_logger';
use Data::Dump 'pp';

sub invoke {
    my ( $self, %args ) = @_;

    my $verbose = !!$args{verbose};

    my @prls = XT::Domain::PRLs::get_all_prls;
    foreach my $prl (@prls){

        # Create TheSchwartz job to dump XTracker stock. We schedule this job before sending message
        # to the PRL to ensure we do the stock dump before we run the job that does reconciliation
        # upon receipt of reply message from the PRL.
        my $prl_name = $prl->name;
        my $prl_amq_identifier = $prl->amq_identifier;
        my $payload = { function => 'dump', prl => $prl_amq_identifier };
        my $job_rq = XT::JQ::DC->new({ funcname => 'Receive::StockControl::ReconcilePrlInventory' });
        try {
            $job_rq->set_payload( $payload );
        }
        catch {
            # Add some logging to help DCOP-432 investigation
            xt_logger->error(
                'Failed to set payload for prl ' . pp(+{$prl->get_columns})
            );
            die $_;
        };
        $job_rq->send_job();

        # Send message to PRL requesting stock dump.
        try {
            $self->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::PRL::PrepareStockFile' => {
                    request_id => DateTime->now->set_time_zone('UTC')->iso8601,
                    prl_name   => $prl_name
                },
            ) unless $args{dryrun};
        }
        catch {
            warn "Couldn't send message to $prl_name: $_\n";
        };
    }
}

1;
