#!/usr/bin/env perl

use strict;
use warnings;

use File::Slurp qw( slurp );
use Text::CSV_XS;
use FindBin qw($Bin);
use Template;
use Getopt::Long;
use Pod::Usage;

my $result = GetOptions(
    'source-file=s' => \(my $source_filename),
    'output-csv=s'  => \(my $csv_filename),
    'output-html=s' => \(my $html_filename),
    'help|h'      => \(my $help),
);

pod2usage(1) if $help;
pod2usage(2) unless $source_filename && ($csv_filename || $html_filename);

# parse the log
my $timing_rows = _prepare_data( $source_filename );

# generate reports
_generate_csv( $csv_filename, $timing_rows ) if $csv_filename;
_generate_html( $html_filename, $timing_rows ) if $html_filename;

######################################################################

sub _prepare_data {
    my $source_filename = shift;

    # open log file
    my $timing_data = slurp( $source_filename )
        or die "Can't open '$source_filename': $!";

    # get count,min,max,total for each method
    my $timing = {};
    for my $timing_line ( split(/\n/, $timing_data) ) {
        my ( $method_name, $elapsed_time ) = split( /,/, $timing_line );

        $timing->{$method_name}{count}++;
        $timing->{$method_name}{total} += $elapsed_time;
        $timing->{$method_name}{min} = $elapsed_time if (($timing->{$method_name}{min} || 99999) > $elapsed_time);
        $timing->{$method_name}{max} = $elapsed_time if (($timing->{$method_name}{max} || 0) < $elapsed_time);
    }

    # calculate averages
    $timing->{$_}{average} = $timing->{$_}{total}/$timing->{$_}{count} for keys %$timing;

    # prepare data for reports
    my $timing_rows = [];
    for my $method_name ( sort { $timing->{$b}{total} <=> $timing->{$a}{total} } keys %$timing ) {
        my $timing = $timing->{$method_name};
        push @{$timing_rows}, { method_name => $method_name, %$timing };
    }

    return $timing_rows;
}

# generate CSV
sub _generate_csv {
    my ( $filename, $timing_rows ) = @_;

    my $csv = Text::CSV_XS->new({ eol => "\n" });
    open( my $fh, '>', $filename ) or die "Can't write CSV file '$filename': $!";
    $csv->print( $fh, [qw( Method Count Min Max Average Total )] );
    for my $timing_row (@$timing_rows) {
        my %timing = %$timing_row;
        $csv->print( $fh, [ @timing{qw( method_name count min max average total )} ] );
    }
    close $fh;
}

# generate HTML
sub _generate_html {
    my ( $filename, $timing_rows ) = @_;

    open( my $html, '>', $filename ) or die "Can't write HTML file '$filename': $!";
    my $template = Template->new({
        INCLUDE_PATH => "$Bin/template",
        OUTPUT => $html,
    });
    $template->process( 'flow_timing_report.html.tt', { timing_rows => $timing_rows } );
    close $html;
}

__END__

=head1 NAME

flow_timing_report.pl - Generate report of logged times for Flow methods

=head1 SYNOPSIS

  flow_timing_report.pl --source-file t/tmp/flow_timing.log --output-csv report.csv --output-html report.html

=cut
