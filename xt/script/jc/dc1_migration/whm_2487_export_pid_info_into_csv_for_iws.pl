#!/opt/xt/xt-perl/bin/perl

=head1 NAME

whm_2487_export_pid_info_into_csv_for_iws.pl - export PID details in a csv file so that
they can be imported into IWS

=head1 DESCRIPTION

The CSV file will contain the following PID information,
product_id, storage_type, description, photo_link, channel

=head1 SYNOPSIS

    perl whm_2487_export_pid_info_into_csv_for_iws.pl

    -help   (optional)
    -export_file   complete path of the export file (required)
    -import_file   complete path of the import file (required)

=cut

use strict;
use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw/schema_handle/;
use Text::CSV_XS;
use Pod::Usage;
use Getopt::Long;

use Readonly;
Readonly my $CHANNEL_JC      => 'JIMMYCHOO.COM';
Readonly my $JC_PHOTO_LINK   => '';
Readonly my $JC_STORAGE_TYPE => 'Flat';

local $|=1;

GetOptions ('export_file=s'  => \( my $export_file ),
            'import_file=s'  => \( my $import_file ),
            'help|?'  => \( my $help ))
            or die("Error in command line arguments. Type -help for more options\n");

if ($help || ! $export_file || ! $import_file) {

    pod2usage(-verbose => 0);
    exit 1;
}

die "\nFile does not exist: $import_file\n\n" if (! -e $import_file);

say 'Starting export...';

my $csv = Text::CSV_XS->new ( { binary => 1,
                                eol    => "\n" } );

open my $report, '>:encoding(UTF-8)', $export_file or die "Error opening export file: $!\n";
open my $fh, "<:encoding(utf8)", $import_file or die "Cannot open file $import_file: $!\n";

my @row = qw (product_id storage_type description photo_link channel);
$csv->print ($report, \@row);

my $pids_completed;

my @cols = @{$csv->getline ($fh)};
$csv->column_names (@cols);
FILE : while ( my $row = $csv->getline_hr( $fh ) ) {

    # just add pid once
    next FILE if ($pids_completed->{$row->{destination_pid}});
    $pids_completed->{$row->{destination_pid}} = 1;

    my $row_number = $csv->record_number();
    say "Starting row $row_number: ";

    say "ERROR: product_id empty" if (! $row->{destination_pid});
    say "Writing product ... $row->{destination_pid}";
    @row = ();
    @row = ($row->{destination_pid}, $JC_STORAGE_TYPE, $row->{description}, $JC_PHOTO_LINK, $CHANNEL_JC);
    $csv->print ($report, \@row);
}

close($report);
$csv->eof or $csv->error_diag();
close $fh;

say '--- Process Complete ---';
