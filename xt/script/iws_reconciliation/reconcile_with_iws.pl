#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

use File::Spec qw( catfile );
use Text::CSV_XS;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Config::Local qw ( config_var );
use XT::Data::StockReconcile::IwsStockReconciler;


# Set-up  -- make sure how we were invoked makes sense
my $export_dirname = '.';
my $start_time = time;

# Stupidest arg processing imaginable

if ($#ARGV == 0) {
    $export_dirname=$ARGV[0];

    die qq{'$export_dirname' is not a directory\n} unless -d $export_dirname;
}
else {
    die qq{Must specify one directory name\n};
}

# Make a reconciler object and get it to do the comparison, returning a hash describing discrepancies.
my $reconciler = XT::Data::StockReconcile::IwsStockReconciler->new;
my $discreps = $reconciler->compare_stock($export_dirname);

# Now create a report of the discrepancies and email it
my $summary = $reconciler->gen_summary($start_time);
my $reportfile = $reconciler->gen_report;
my $email = config_var('Reconciliation','report_email') ||
    die "Missing Reconciliation/report_email in config";
$reconciler->email_report( $summary, $reportfile, 'IWS', $email );


1;

__END__

=head1 Introduction

This script reconciles two data exports, one from XTracker and
one from IWS, and reports any differences it finds.


=head2 Inputs

Two files are expected, one of which must contain a stock-reconciliation
export from XTracker, and the other must contain a stock-reconciliation
export from IWS.

Each file ought to consist of newline-terminated records that
contain the following comma-separated columns:

=over 4

=item channel name

=item SKU

=item status

=item count of unavailable items

=item count of allocated items

=item count of available items

=back

Additionally, the first line of each file may contain column headings,
in which case it will be ignored.

Additionally, any line in the file can start with a # character,
in which case it's treated as a comment. This allows the export
files to be labelled by the export process, so that things like
date and time of export can be embedded in them.  (This is not
part of any CSV so-called standard.  If this troubles you,
the author invites you to bite him.)

(We can pull both of the preceding stunts, while claiming that the
files are still CSV-ish, because we are only expecting channel names
in the first column, and are chosen from a limited set of values.)

=head2 Definitions

The following definitions are used for the above columns:

=over 4

=item status

This is the stock status of the SKU. Expected values are: I<Main>,
I<Sample>, I<Faulty>, I<RTV>, I<Dead>.

=item unavailable items

These are items where stock has been received, and pre-advice notices
sent, but where the items are not yet putaway into main stock.

=item available items

These are items that are available from stock (in XTracker terms,
there is a positive amount of this item in the C<quantity> table).

=item allocated items

These are items that are associated with a shipment that is
being dealt with.  Specifically, associated with a shipment item
that is I<selected>, I<picked>, I<packed>, and where the shipment
itself is in I<processing>.

=back

=head2 Process

We inhale the XTracker export file first, and perform some sanity checks on it.

Then, for each record in the IWS export file, we compare it with the matching
record in XTracker that has the same channel/SKU/status combination.

There are four possible results:

=over 4

=item XTracker present, IWS missing

=item XTracker missing, IWS present

=item both present, but some values differ

=item both present, and both identical

=back

We don't report records in the last of those states (both identical), but
the other three generate a record in our output describing the problem.

At the end of processing, we summarize how many of each kind of result
we've found, including a total of the identical records, so that it's
clear that they were correctly handled, and not just missed.

=head2 Invocation

The script is designed to be invoked both interactively, for quick ad-hoc
checks of data to hand, and in a more controlled way, to allow for
automated capture and handling of reconciliation reports, perhaps from cron.

=head3 Two file names

If invoked loosely, such as interactively from the command line, it expects
to be given two arguments that are taken to be the names of the XTracker and IWS export
files, and it sends only the summary of its comparison to standard output, with any
errors on standard error.

Because both files have congruent formats, they can be provided on
the command line in either order, and the output will be reported
relative to the filenames given, with the first file being treated as
the reference file, and the second as the comparison file.

=head3 One directory name

If invoked with a single argument, then it must be a directory name.
In that directory, there must be two input files, named:

=over 4

=item xt_stock_export.csv

=item iws_stock_export.csv

=back

In that same directory, after successful operation, four output files will
be written:

=over 4

=item skus_in_xt_only.csv

=item skus_in_iws_only.csv

=item skus_that_differ.csv

=item summary_report.txt

=back

A fifth will appear should any problems be found with the data:

=over 4

=item error_report.txt

=back

The second invocation style is intended to be harnessable by automated processes,
and so uses the directory to bundle input and output files together for later
review without danger of previous runs being accidentally trashed.

Note that, in the second case, the file names are B<fixed>, since they're
effectively a silly little API.  This is necessary so that the script can
accurately know which export is from XT and which from IWS, other than
by divining it from the contents.

=cut

