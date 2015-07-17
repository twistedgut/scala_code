#!/opt/xt/xt-perl/bin/perl
#
# spit out a list of order file names in the order they need to be
# processed

use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

# The XT_LOGCONF env var must be set before XTracker::Logfile is imported via
# the XTracker:: 'use' chain otherwise it will pick up 'default.conf'
BEGIN {
    if( ! defined $ENV{XT_LOGCONF} ){
        $ENV{XT_LOGCONF} = 'order_importer.conf';
    }
}

use XT::Importer::FCPImport qw( :xml_filename );
say foreach read_sorted_xml_filenames_from_directory( $ARGV[0] );
