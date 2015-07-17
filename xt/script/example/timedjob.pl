#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;
use lib '/opt/xt/deploy/xtracker/lib';
use FindBin::libs qw( base=lib_dynamic );
use XT::JobQueue;

=head1 NAME

queuejob.pl - insert a task into the job-queue

=pod DESCRIPTION

This script demonstrates how to queue  "Export To PWS" task"

=head1 AUTHOR

Chisel Wright C<< <chisel.wright@net-a-porter.com> >>

=cut

# get a new queuing object
my $queuer = XT::JobQueue->new;

# queue an export of promo #49
$queuer->insert_job(
    'Promotion::ExportPWS',
    {
        feedback_to     => {
            operators       => [ 399 ],
        },
        promotion_id    => 71,

        run_after       => (time() + (60 * 5)), # don't start for 5 minutes
    },
) or die $!;

# some user feedback
print "done\n";
