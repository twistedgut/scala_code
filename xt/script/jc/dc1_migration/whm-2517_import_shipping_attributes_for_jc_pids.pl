#!/opt/xt/xt-perl/bin/perl

=head1 NAME

whm-2517_import_shipping_attributes_for_jc_pids.pl - import shipping attributes
of pids from csv file to XT DB

=head1 DESCRIPTION

The CSV file is generated from an export from JC DB and will have following columns:
source_pid,source_size_id,destination_pid,destination_size_id,style_number,
designer_colour,size_name,weight,country_code,fabric_content
should be comma separated file

=head1 SYNOPSIS

    perl whm-2517_import_shipping_attributes_for_jc_pids.pl

    -help   (optional)
    -file   complete path of the shipping attributes file to be imported (required)

=cut

use strict;
use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Database qw/schema_handle/;

use Pod::Usage;
use Text::CSV_XS;
use Getopt::Long;
local $|=1;

GetOptions ('file=s' => \( my $import_file ),
            'help|?' => \( my $help )) or die("Error in command line arguments. Type -help for more options\n");

if ($help || ! $import_file) {

    pod2usage(-verbose => 0);
    exit 1;
}

die "\nFile does not exist: $import_file\n\n" if (! -e $import_file);

my $schema = schema_handle();
my $csv    = Text::CSV_XS->new ( { binary => 1 } );

# input file contains data at sku level, so no point adding same product again
# once the product has been updated we will store info in following hash
my $pid_added;
my @error_pids;
open my $fh, "<:encoding(utf8)", $import_file or die "Cannot open file $import_file: $!\n";
my @cols = @{$csv->getline ($fh)};
$csv->column_names (@cols);
FILE : while ( my $row = $csv->getline_hr( $fh ) ) {

    my $row_number = $csv->record_number();
    say "Starting row $row_number: ";

    # Toddy mentioned to ignore rows without product id or errored pids
    if ((! $row->{destination_pid}) || ($row->{errored} eq 'Yes')) {
        say "No destination PID or errored PID, moving to next";
        next FILE;
    }

    # if the product has already been updated, move to next
    if ( $pid_added->{$row->{destination_pid}} ) {
        say "Row $row_number: Pid $row->{destination_pid} already updated, moving to next";
        next FILE;
    }

    my $product = _check_pid_row_exists( $row );
    if (! $product) {
        say "Error: PID $row->{destination_pid} does not exist in the database";
        push @error_pids, $row->{destination_pid};
        next FILE;
    }

    # update the row
    try {
        say "Updating row in XT... ";
        _update_pid_row_in_xt( $product, $row );

        # store product so that we dont update it again
        $pid_added->{$row->{destination_pid}} = 1;
    } catch {
        die "Could not import Shipping restriction data: $_\n";
    }
}
$csv->eof or $csv->error_diag();
close $fh;

say "Following pids do not exist in DB or have invalid country " .
join (',', @error_pids) if (@error_pids);

say "------------ Process Complete ------------";


# If row already exist in DB, move to the next one
sub _check_pid_row_exists {
    my ($row) = @_;

    my $product = $schema->resultset('Public::ShippingAttribute')
                           ->find({ product_id => $row->{destination_pid}});
    return ($product || 0);
}


# Insert JC quantity rows into XT from a CSV file
sub _update_pid_row_in_xt {
    my ($product, $row) = @_;

    my $country_id = undef;

    if ($row->{country_code}) {

        $country_id = $schema->resultset('Public::Country')
                          ->search({ code => $row->{country_code} })
                          ->get_column('id')->single;

        if (! $country_id) {
            say "Error: PID $row->{destination_pid} has invalid country";
            push @error_pids, $row->{destination_pid};
            return;
        }
    }

    $product->update({ weight         => $row->{weight} || undef,
                       fabric_content => $row->{fabric_content},
                       country_id     => $country_id});
}
