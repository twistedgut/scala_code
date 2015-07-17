package XT::JobQueue::Promotion;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use XTracker::Database qw( get_database_handle );
use XTracker::Constants::FromDB qw( :promotion_status );

# the work function called by TheSchwartz
sub work {
    my $class   = shift;
    my $job     = shift;
    my ($promotion_domain);

    # create a worker OBJECT
    my $self = $class->new({job => $job});
    # make sure we're still OK to continue
    if ($job->exit_status()) {
        # we failed!
        warn "failed to get promotion-domain information for job\n";
        return;
    }

    # start the actual work
    eval {
        $self->start_work();
    };

    # deal with eval failures
    if ($@) {
        my $error = $@; # so we don't lost it
        warn "eval caught: $error";
        $job->failed($error, $PROMOTION_STATUS__JOB_FAILED);
        $self->get_promotion_domain->update_detail_status(
            $self->get_promotion_id,
            $PROMOTION_STATUS__JOB_FAILED
        );
        return;
    }


    # if we didn't fail, we completed
    if (not $job->exit_status()) {
        $job->completed();
    }
    else {
        $job->failed(q{No Reason Given}, $PROMOTION_STATUS__JOB_FAILED);
        $self->get_promotion_domain->update_detail_status(
            $self->get_promotion_id,
            $PROMOTION_STATUS__JOB_FAILED
        );
    }

    return;
}

# XT::JobQueue common functionality
use Class::Std;
{
    my %job_of              :ATTR( get => 'job',                set => 'job'                );
    my %promotion_id_of     :ATTR( get => 'promotion_id',       set => 'promotion_id'       );
    my %promotion_domain_of :ATTR( get => 'promotion_domain',   set => 'promotion_domain'   );

    my %messager_of         :ATTR( get => 'messager',           set => 'messager'           );
    my %schema_of           :ATTR( get => 'schema',             set => 'schema'             );
    my %feedback_to_of      :ATTR( get => 'feedback_to',        set => 'feedback_to'        );

    sub START {
        my ($self, $oid, $arg_ref) = @_;

        # a handy schema object
        my $schema = get_database_handle(
            {
                name => 'xtracker_schema',
                type => 'transaction'
            }
        );
        $self->set_schema( $schema );

        # a handy message object
        $self->set_messager(
            XT::Domain::Messages->new({ schema => $self->get_schema })
        );

        # store the job
        $self->set_job( $arg_ref->{job} );
        # store where to send feedback to
        $self->set_feedback_to( $self->get_job->arg->{feedback_to} );
        # prepare the domain
        $self->prepare_domain();

        return;
    }

    sub prepare_domain {
        my $self    = shift;
        my $job     = $self->get_job();
        my ($schema, $promotion_domain);

        # make sure someone tells us what the promo is
        if (not defined $job->arg->{promotion_id}) {
            $job->failed('promotion-id not specified');
        }

        # store the promotion-id
        $self->set_promotion_id( $job->arg->{promotion_id} );

        # get the promotion
        eval {
            $promotion_domain = XT::Domain::Promotion->new(
                {
                    schema => $self->get_schema,
                }
            );
        };
        if ($@) {
            my $error = $@; # so we don't lost it
            warn $error;
            $job->failed($error);
            die $error;
        }

        if (not defined $promotion_domain) {
            $job->failed('could not create new instance of XT::Domain::Promotion');
            return;
        }

        # save the promotion_domain as an object attribute
        $self->set_promotion_domain( $promotion_domain );

        return;
    }
}

1;
