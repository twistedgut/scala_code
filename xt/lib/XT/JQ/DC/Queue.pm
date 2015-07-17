package XT::JQ::DC::Queue;
# vim: ts=8 sts=4 et sw=4 sr sta

use Moose; # automagically gives us strict and warnings
use MooseX::FollowPBP;
use Module::Runtime 'require_module';
use Try::Tiny;
use XTracker::Database;
use XTracker::Config::Local qw( config_var );

use Log::Log4perl qw(:easy);
# because of the convoluted way we use and layer all the JQ modules, we
# should already be initialised when we get here
#if (not Log::Log4perl->initialized()) {
#    warn 'l4p not initialized in ' . __PACKAGE__ . '; please inform Chisel';
#}

extends 'XT::Common::JQ::Queue' => { -version => 0.1.10 };

has '+pidfile' => (
    default => sub {
        config_var('job_queue', 'pidfilebase')
      . '.'
      . (shift->get_worker_group || 'MISSING')
      . '.pid'
    },
    lazy => 1,
);

has '+num_children' => (
    default => sub {
        config_var('job_queue', 'num_procs')
    }
);
has '+default_feedback_to' => (
    default => sub {
        config_var('job_queue', 'default_feedback_to')
    }
);

has worker_group => (
    init_arg => 'worker-group',
    isa => 'Str',
    is => 'rw'
);

sub _prepare_dsn {
    my $self    = shift;

    return {
        dsn   => config_var('Database_Job_Queue', 'dsn'),
        user  => config_var('Database_Job_Queue', 'user'),
        pass  => config_var('Database_Job_Queue', 'pass'),
    };
}

sub BUILD {
    my ( $self, $argref ) = @_;
    my $jobs;

    # it seems as though every time we process a job, BUILD is called
    # without defined $argref... whereas the setup is only required
    # when we first start the job_queue
    return 0 unless defined $argref->{worker_group};

    # for use in the require() shortly
    my $namespace = $self->get_namespace;
    $namespace =~ s/::\W+$//;

    $self->set_worker_group( $argref->{worker_group} );

    if ($self->get_worker_group eq 'LEGACY') {
        $jobs = $self->all_jobs(
            config_var('job_queue', 'worker-group')
        );
    }
    else {
        # the list of jobs we can do
        eval {
            $jobs =
                config_var('job_queue', 'worker-group')
                    ->{ $self->get_worker_group }{job};
        };
        # handle errors
        if (my $err = $@) {
            LOGCLUCK( $err );
        }
    }

    # handle lack of jobs
    if (not defined $jobs) {
        LOGDIE "No jobs in worker-group: " . $self->get_worker_group . "\n";
    }
    # turn single jobs (string) into a list
    if (not ref($jobs)) {
        $jobs = [ $jobs ];
    }

    # require each module; tell the jobqueue we can_do() them
    foreach my $function (@$jobs) {
        my $fullname = $namespace . $function;

        try { require_module $fullname } # require
        catch { LOGCLUCK( $_ ); 0 } # give feedback (if any)
            or next; # this has to be outside of the catch coderef

        # admit to being able to do the function
        $self->can_do($function);
    }

}

no Moose;

1;
__END__
