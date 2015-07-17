#!/opt/xt/xt-perl/bin/perl

use NAP::policy;
use FindBin::libs;

use DateTime;
use XTracker::Logfile 'xt_logger';
use XTracker::Printers::PrintJobs;

=head1 cancel_old_printjobs

Automatically cancels print jobs older than 6 hours (see CUTOFF_MINUTES)
for the user this script is invoked as.

=synopsis

./cancel_old_printjobs

This script takes no arguments.

=cut

my $CUTOFF_MINUTES = 60 * 2; # 2 hours

sub main {

    my $cutoff = DateTime->now(time_zone=>'UTC')->subtract(minutes => $CUTOFF_MINUTES);

    my @print_jobs = XTracker::Printers::PrintJobs->new->get_print_jobs;

    xt_logger->info(sprintf("scanning %d print jobs and erasing ones older than %s",
        scalar(@print_jobs),
        $cutoff->strftime("%a %b %Y %H:%M:%S %Z")
    ));

    my $cancelled_count = 0;

    foreach my $print_job (@print_jobs) {
        if ($print_job->date < $cutoff) {
            xt_logger->info(sprintf("job before cutoff (job_id=%s,date=%s)",
                $print_job->job_id,
                $print_job->date
            ));

            try {
                $print_job->cancel;
            } catch {
                xt_logger->warn("unable to cancel old print job: $_");
            };

            $cancelled_count++;
        }
    }

    xt_logger->info("script finished. $cancelled_count print jobs cancelled");

}

main;
