package XT::JobQueue;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use TheSchwartz;
use TheSchwartz::Job;
use XTracker::Database;
use XTracker::Config::Local qw( config_var );
use Carp;
use File::Pid;

# object attributes
my %client_of       :ATTR( get => 'client',     set => 'client'    );
my %namespace_of    :ATTR( get => 'namespace',  set => 'namespace' );

use Class::Std;
{
    sub START {
        my ($self, $obj_ID, $arg_ref) = @_;

        # set the namespace, based on ourself
        $self->set_namespace( (ref($self) || __PACKAGE__) . q{::} );

        # TODO - make this not crap
        # yes totally wrong to use a "private" method - CCW :)
        my $params = XTracker::Database::_db_connect_params(
            {
                name       => 'jobqueue_schema',
                # We'd like this to be a true value BUT this has been a
                # 'transactional' connection since it was first written, and I
                # don't want to break the jobqueue - not sure how much coverage
                # we have. We should look at switching this to autocommit 1 to
                # make it DBIC-friendly when we can ensure that it won't break
                # anything.
                autocommit => 0,
            }
        );
        my $dsn = XTracker::Database::_connection_string( $params );

        # TODO - make this not crap
        my $client = TheSchwartz->new(
            databases => [ {
                dsn  => $dsn,
                user => 'www',
                pass => 'www',
            } ],
            verbose => ($arg_ref->{verbose} || 0),
        );

        # save the client for later use
        $self->set_client( $client );

        return;
    }

    sub can_do {
        my ($self, $funcname) = @_;

        # append our namespace to give the correct funcname
        $self->get_client()->can_do(
            $self->get_namespace . $funcname,
        )
            or die "$!";

        return 1;
    }

    sub insert_job {
        my ($self, $funcname, $argref) = @_;
        # tell people where to look for more detailed information
        my $message_perldoc = qq{for more info: perldoc XT::Domain::Messages\n};

        # warn people if they queue jobs without anyone to send messages to
        if (not defined $argref->{feedback_to}) {
            carp q{job queued without 'feedback_to' data};
        }
        # make sure the feedback_to looks sane(ish)
        if ('HASH' ne ref($argref->{feedback_to})) {
            carp q{'feedback_to' value should be a hash-ref};
            warn ${message_perldoc};
            delete $argref->{feedback_to}; # nuke invalid feedback_to
        }
        else {
            # should only have one key-value pair
            if (keys(%{$argref->{feedback_to}}) > 1) {
                carp q{'feedback_to' should only have one key-value pair};
                warn ${message_perldoc};
                delete $argref->{feedback_to}; # nuke invalid feedback_to
            }
            # should be one of the known options to XT::Domain::Messages
            else {
                my @ok_options = qw/operators department_id all/;
                my $key = (keys(%{$argref->{feedback_to}}))[0];
                my $matches = grep { m{\A$key\z} } @ok_options;
                if (not $matches) {
                    carp qq{'$key' is not a 'feedback_to' key};
                    warn ${message_perldoc};
                    delete $argref->{feedback_to}; # nuke invalid feedback_to
                }
            }
        }

        # manually create the job, allowing us to (optionally) set a time
        # for the job to be run after
        my $run_after = delete $argref->{run_after};
        my $job = TheSchwartz::Job->new(
            #funcname    => $self->get_namespace . $funcname,
            funcname    => $funcname,
            arg         => $argref,
            run_after   => $run_after, # potentially don't start for a while
        );

        # add the job
        $self->get_client()->insert( $job)
            or die "$!";

        return 1;
    }

    sub is_running {
        my $self = shift;

        my (undef, undef, $uid) = getpwnam('xt-jq');
        if ($> != $uid) {
            my $current_username = getpwuid($<);
            die "the job-queue test should be run as 'xt-jq' (same user as the apache server) We are $current_username [id=$>]\n";
        }

        my $pidfile = File::Pid->new(
            {
                file => config_var('job_queue','pidfile'),
            }
        );

        if (my $num = $pidfile->running ) {
            #warn "Already running: $num\n";
            return $num; # return the PID, in case it's useful
        }
        else {
            #warn "not running? you sure?\n";
            return 0;
        }
    }

    sub work {
        my $self = shift;
        $self->get_client()->work;
        # work() never returns?
        return;
    }

    sub work_once {
        my $self = shift;
        $self->get_client()->work_once;
        return;
    }

}

1;

__END__
