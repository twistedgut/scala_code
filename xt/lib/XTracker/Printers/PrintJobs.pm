package XTracker::Printers::PrintJobs;

use NAP::policy 'class';

use DateTime::Format::Strptime;
use XTracker::Printers::PrintJob;

=head1 NAME

XTracker::Printers::PrintJobs - Print Jobs from XTracker

=head1 DESCRIPTION

Perl wrappers of lpstat allowing you to see waiting print jobs

=cut

my $lp_stat_timezone='UTC';
my $lp_stat_command = '/usr/bin/lpstat';

has 'lp_stat_date_parser' => (
    is => 'ro',
    default => sub {
        return DateTime::Format::Strptime->new(
            pattern  => '%a %d %b %Y %H:%M:%S %Z',
            on_error => 'croak'
        );
    },
    handles => {
        '_parse_lp_stat_date' => 'parse_datetime'
    }
);

=head2 get_print_jobs

Returns a list of XTracker::Printers::PrintJob objects
for each print job which is waiting to be processed.

=cut

sub get_print_jobs {
    my $self = shift;

    my @print_jobs;

    my @lp_stat_lines;

    {
        local $ENV{TZ}=$lp_stat_timezone;
        @lp_stat_lines = `$lp_stat_command`; ## no critic(ProhibitBacktickOperators)
    }

    foreach my $lp_stat_entry (@lp_stat_lines) {

        my ($job_id, $user, $size, $date) =
            $lp_stat_entry =~ /^(\S+)\s+(\S+)\s+(\d+)\s+(.*)$/;

        if (!$job_id) {
            die("Can't retrieve print jobs. Unable to parse lpstat output");
        }

        my $print_job = XTracker::Printers::PrintJob->new({
            job_id => $job_id,
            user   => $user,
            size   => $size,
            date   => $self->_parse_lp_stat_date($date)
        });

        push(@print_jobs, $print_job);
    }

    return @print_jobs;
}

