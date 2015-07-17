#!/opt/xt/xt-perl/bin/perl

=head1 NAME

label.pl

=head1 DESCRIPTION

Print a test MrP label:

    .----------------------.
    |   _Your name here_   |
    |                      |
    |      MR PORTER       |
    '----------------------'

NOTE: This script was more useful when we printed directly to the Zebra
printers socket. Since WHM-587 (June 2014) we print the normal way via XT::LP
and all the code which generates the PNG and ZPL was moved out of Shipment into
PrintFunctions.

Printing must be enabled in XTracker config for this script to do anything.

=head1 SYNOPSIS

label.pl "Sticker text" goodsinBarcodeSmall

Where goodsinBarcodeSmall is the name of a printer which is set up in CUPS

=cut

use warnings;
use strict;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Config::Local qw(config_var);
use XTracker::Printers::Zebra::PNG;
use XTracker::Database qw(xtracker_schema);
use XTracker::PrintFunctions qw( print_mrp_sticker );

my $schema = xtracker_schema;
my $base_dir = config_var('SystemPaths','xtdc_base_dir');

my ($text,$printer_name) = @ARGV;
die "usage: '$0 \"Sticker text\" goodsinBarcodeSmall'" unless ($text && $printer_name);

print_mrp_sticker({
    text => $text,
    printer => $printer_name,
    copies => 1,
});
