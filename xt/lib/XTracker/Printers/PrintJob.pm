package XTracker::Printers::PrintJob;

use NAP::policy 'class';
use XTracker::Logfile 'xt_logger';

=head1 NAME

XTracker::Printers::PrintJob - Represents a Print job (only from lpstat)

=head1 DESCRIPTION

Represents a print job currently in progress, (from the output of lpstat)
and provides the ability to cancel it.

=cut

has job_id => (is => 'ro', isa => 'Str', required => 1);
has user   => (is => 'ro', isa => 'Str', required => 1);
has size   => (is => 'ro', isa => 'Int', required => 1); # bytes
has date   => (is => 'ro', isa => 'DateTime', required => 1);

=head2 cancel

Cancel the print job.
Invokes /usr/bin/cancel.
make sure job_id in object isn't user tamperable.
may throw exception.

=cut

sub cancel {
    my $self = shift;
    xt_logger->info("cancelling print job (job_id=". $self->job_id .")");
    my $retval = system("/usr/bin/cancel", $self->job_id); # retval: did it execute
    $retval = $? >> 8 if ($retval == 0); # retval: exit code.

    if ($retval != 0) {
        die (sprintf("cant cancel print job (job_id=%s,exit_code=%d)",
            $self->job_id,
            $retval
        ));
    }

}
