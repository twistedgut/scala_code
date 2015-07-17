#!/opt/xt/xt-perl/bin/perl

=head1 NAME

ph_sticker.pl

=head1 DESCRIPTION

Print PH labels:

    .----------------------.
    |   || |||| |||| |||   |  <--- barcode
    |   PH001              |
    '----------------------'

Printing must be enabled in XTracker config for this script to do anything.

=head1 SYNOPSIS

ph_sticker.pl goodsinBarcodeSmall {1..10}

Where goodsinBarcodeSmall is the name of a printer which is set up in CUPS

=cut

use warnings;
use strict;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Config::Local qw(config_var);
use XTracker::PrintFunctions 'path_for_print_document';
use XT::LP;

my ($printer, @phnum) = @ARGV;
die "usage: '$0 10.5.7.230 {1..10}'" unless $printer && @phnum;

my $dry_run = 0; # set to skip printing and display documents instead

for my $phnum (@phnum) {
    my $barcode = 'PH'.sprintf('%03i', $phnum);
    my $count = 2; # two copies of each

#################################
#    ^                          #
#    |                          #
#    v                          #
#<-->+------------+ ^           #
#    | FOx,y      | |           #
#    |            | BCN,400     #
#    |            | |           #
#    +------------+ v           #
#    <---- BY9 --->             #
#    FOx,y                      #
#                               #
#################################

    my $content = qq/
^XA
^MUd,200,300
^BY9,2,10
^FO100,120^BCN,250,N,N^FD$barcode^FS
^FO100,385^A0N,225,200^FD$barcode^FS
^PQ$count^FS
^XZ
/;
    if ($dry_run) {
        print '=' x 20, "\n", $content;
        next;
    }

    print_ph_sticker($printer, $content);

}

sub print_ph_sticker {
    my ($printer, $content) = @_;

    my $temp_sticker_path = path_for_print_document({
        document_type => 'temp',
        id => 'ph_sticker',
        extension => 'txt',
    });

    my $output_fh = IO::File->new( $temp_sticker_path, '>' )
      or die "Unable to open file '$temp_sticker_path': $!\n";
    $output_fh->binmode;
    $output_fh->print( $content );
    $output_fh->close;

    my $printer_info = XTracker::PrinterMatrix->new->get_printer_by_name($printer);

    XT::LP->print(
        {
            printer     => $printer_info->{lp_name},
            copies      => 1,
            filename    => $temp_sticker_path,
        }
    );
}
