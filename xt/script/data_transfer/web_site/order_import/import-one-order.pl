#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

# The XT_LOGCONF env var must be set before XTracker::Logfile is imported via
# the XTracker:: 'use' chain otherwise it will pick up 'default.conf'
BEGIN {
    if( ! defined $ENV{XT_LOGCONF} ){
        $ENV{XT_LOGCONF} = 'order_importer.conf';
    }
}

use XT::Importer::FCPImport;
XT::Importer::FCPImport::import_one_file({   readyfile => $ENV{INPUT_FILE},
                                           successfile => $ENV{SUCCESS_FILE},
                                           failurefile => $ENV{FAILURE_FILE}
                                         });

exit 0;
