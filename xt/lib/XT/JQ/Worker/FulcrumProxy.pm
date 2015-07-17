package XT::JQ::Worker::FulcrumProxy;

use Moose;
use MooseX::Types::Moose qw(Str);
use Carp;
use XT::JQ::Central::Queue;
use namespace::clean -except => ['meta'];

extends 'XT::JQ::Worker';

has fulcrum_jobname => (
    #is => 'ro',
    isa => Str,
    required => 1,

    reader  => 'get_fulcrum_jobname',
);

use Data::Dump qw/pp/;

sub do_the_task {
    my($self,$job) = @_;
    my $jobname = $self->get_fulcrum_jobname;

    if (not defined $jobname) {
        die __PACKAGE__ ." - trying to send job to fulcrum but not set fulcrum_jobname";
    }

    $self->add_fulcrum_job(
        {
            jobname     => $jobname,
            jobdata     => $job->arg,
        }
    );

    $job->completed();
    return;
}

sub add_fulcrum_job {
    my $self    = shift;
    my $argref  = shift;
    my ($remote_queue);

    ## validate arguments

    # we need a job/function name
    if (not defined $argref->{jobname}) {
        carp "'jobname' needs to be specified";
        return;
    }

    # we need data for the job
    if (not defined $argref->{jobdata}) {
        carp "'jobdata' needs to be specified";
        return;
    }

    # create queue object for desired DC
    $remote_queue = XT::JQ::Central::Queue->new();

    if (not defined $remote_queue) {
        carp "couldn't grab a queue for fulcrum";
        return;
    }

    # insert job
    my $h = $remote_queue->insert_job(
        $argref->{jobname},
        $argref->{jobdata},
    );

    return $h;
}

1;

__END__

=head1 NAME

XT::JQ::Worker::FulcrumProxy - a class made for jobs that just punt stuff to Fulcrum

=head1 DESCRIPTION

This class extends XT::JQ::Worker to handle the task of just pushing to Fulcrum.

=head1 SYNOPSIS

 package XT::JQ::Central::Foo;

 use Moose;
 use MooseX::Types::Moose qw(Str Int Num);
 use MooseX::Types::Structured qw(Dict Tuple);

 use namespace::clean -except => 'meta';

 with 'XT::JQ::Worker';

 has '+fulcrum_jobname' => ( default => 'Operator::Import' );

 no Moose;


 sub check_job_args {
     my ($class, $job) = @_;
     my @errors;
     eval {
        $class->new($job->arg);
     };
     push @errors, $@ if ($@);

     return @errors;
 }


