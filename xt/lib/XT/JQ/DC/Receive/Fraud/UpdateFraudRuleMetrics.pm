package XT::JQ::DC::Receive::Fraud::UpdateFraudRuleMetrics;

use Moose;

use MooseX::Types::Moose        qw( Str Int Maybe ArrayRef );
use MooseX::Types::Structured   qw( Dict );

use XTracker::Logfile           qw( xt_logger );

use Try::Tiny;

use Benchmark       qw( :hireswallclock );


use namespace::clean -except => 'meta';


extends 'XT::JQ::Worker';


has payload => (
    is => 'ro',
    isa => Dict[
        job_tag                      => Str,
        decisioning_archived_rule_id => Maybe[Int],
        archived_rule_ids_used       => ArrayRef[Int],
    ],
    required => 1,
);

has logger => (
    is => 'ro',
    default => sub { return xt_logger('XT::JQ::DC'); }
);


sub do_the_task {
    my ($self, $job) = @_;
    my $error    = "";

    my $schema = $self->schema;

    my $job_tag = $self->payload->{job_tag};

    my $archived_ids = $self->payload->{archived_rule_ids_used};
    my $deciding_id  = $self->payload->{decisioning_archived_rule_id};

    my $benchmark_log = xt_logger('Benchmark');

    # set-up how to increase the metric counters
    my $used_metric    = { metric_used    => \'metric_used + 1' };
    my $decided_metric = { metric_decided => \'metric_decided + 1' };

    my $benchmark_start = Benchmark->new;
    my $no_error        = 0;

    # flag to be set if no Live Rules could be
    # found and it uses the Archived Rules instead
    my $updated_archived_rules = 0;

    try {
        $schema->txn_do( sub {
            my $live_rule_rs  = $schema->resultset('Fraud::LiveRule');
            my $used_rules_rs = $live_rule_rs->search( {
                archived_rule_id => { IN => $archived_ids },
            } );

            # if there aren't any Live Rules with the required 'archived_rule_id'
            # then the old Live Rules must have been replaced so then go and
            # update the Metric counters on the actual Archived Rule Records
            if ( $used_rules_rs->count > 0 ) {
                # there are Live Rules
                $used_rules_rs->update( $used_metric );

                if ( $deciding_id ) {
                    my $deciding_rule = $live_rule_rs->find( {
                        archived_rule_id => $deciding_id,
                    } );
                    $deciding_rule->update( $decided_metric )
                                if ( $deciding_rule );
                }
            }
            else {
                # no Live Rules, use the Archived versions
                $updated_archived_rules = 1;
                my $archived_rule_rs = $schema->resultset('Fraud::ArchivedRule');

                $used_rules_rs = $archived_rule_rs->search( {
                    id => { IN => $archived_ids },
                } );
                $used_rules_rs->update( $used_metric );

                if ( $deciding_id ) {
                    my $deciding_rule = $archived_rule_rs->find( $deciding_id );
                    $deciding_rule->update( $decided_metric )
                                if ( $deciding_rule );
                }
            }
        } );
        $no_error = 1;
    }
    catch {
        $error = $_;
        $no_error = 0;
        $self->logger->error( qq{Failed job with error: $error} );
        $job->failed( $error );
    };

    if ( $no_error ) {
        my $benchmark_stop = Benchmark->new;
        $benchmark_log->info(
            "JQ, Update Fraud Rule Metrics: Tag - '${job_tag}', " .
            ( $updated_archived_rules ? 'USING ARCHIVED RULES, ' : '' ) .
            "Number of Rules Used: '" . scalar( @{ $archived_ids } ) . "', " .
            "Deciding Rule Id: '" . ( $deciding_id // 'undef' ) . "', " .
            "Total Time = '" . timestr( timediff( $benchmark_stop, $benchmark_start ), 'all' ) . "'"
        );
    }

    return;
}

sub check_job_payload {
    my ($self, $job) = @_;
    return ();
}


1;

__END__

=head1 NAME

XT::JQ::DC::Receive::Fraud::UpdateFraudRuleMetrics

=head1 DESCRIPTION

Expected Payload should look like:

    my $job_payload    = {
        job_tag    => 'some String',            # something to tag the job with to give it context
        decisioning_archived_rule_id => 4,      # the Archived Rule Id of the deciding Rule, can be 'undef'
        archived_rule_ids_used => [ 1, 3, 4 ]   # list of Archived Rule Ids
    };

This Worker will update the Metrics for 'used' & 'decided' counts on the Live Rule records whose
'arhived_rule_id' fields match those in the Payload. If new Live Rules have been published whilst
the Job has been sitting in the Queue then update the same Metrics on the actual Archived Rules
for the old Live Rules.

=cut
