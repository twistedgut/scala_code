#!perl

use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long;
use DateTime;
use Pod::Usage;

use XTracker::Script::Dematic::LogSimReport;

=head1 NAME

script/oneoffs/whm/produce_order_data_for_logsim.pl

=head1 DESCRIPTION

For provided period fetches shipment related data needed by LogSim.

Results are CSV files.

=head1 SYNOPSIS

In terminal run following command:

    perl script/oneoffs/whm/produce_order_data_for_logsim.pl \
        [ --dump-directory=/path/to/directory/with/results ]
        [ --result-filename=filename_with_result_report ]
        [ --date-start ]
        [ --date-end ]
        [ --silent]

All parameters in "[ ... ]" are optional, if they are not provided default
values are used. Please read script's output to see where results were placed.

Here are default values:

* dump-directory: I</tmp/>

* result-filename: I<logsim_report.csv>

* date-end: Current datetime

* date-start: the very beginning of yesterday

=cut

# just to make sure user is constantly updated
local $| = 1;

my %opt;

my $result = GetOptions( \%opt,
    'help|h|?',
    'silent',
    'dump-directory=s',
    'result-filename=s',
    'date-start=s',
    'date-end=s',
);

pod2usage(1) if !$result || $opt{help};

my $report = XTracker::Script::Dematic::LogSimReport->new();

$report->verbose(0) if $opt{silent};

my $date_start = $opt{'date-start'}
    || DateTime::Format::Pg->format_datetime(
        DateTime->now->add(days => -1)->truncate(to => 'day')
    );
my $date_end   = $opt{'date-end'}
    || DateTime::Format::Pg->format_datetime( DateTime->now );
my $result_filename = $opt{'result-filename'} || 'logsim_report.csv';

$report->csv_directory($opt{'dump-directory'} || '/tmp');

$report->invoke({
    date_start      => $date_start,
    date_end        => $date_end,
    result_filename => $result_filename,
});
