#!/opt/xt/xt-perl/bin/perl

# Debugging script for monitoring files written to the print directory, and
# printing their contents (and meta-data) to STDOUT.

use strict;
use warnings;
use lib 'lib';
use FindBin::libs qw( base=lib_dynamic );
use lib 't/lib';
use Data::Dumper;

use Test::XTracker::LoadTestConfig;
use Test::XTracker::PrintDocs;

my $print_directory = Test::XTracker::PrintDocs->new();
print "Monitoring: " . $print_directory->read_directory . "\n";

while ( 1 ) {
    for my $doc ( $print_directory->new_files ) {
        print "Filename: " . $doc->filename  . "\n"; # Relative to printdoc dir

        my $content = eval { $doc->as_data };
        if ( $@ ) {
            print "Can't parse this file\n";
        } else {
            print Dumper $content;
        }
    }
}
