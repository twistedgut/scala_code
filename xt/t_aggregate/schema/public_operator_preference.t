#!/usr/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

# load the module that provides all of the common test functionality
use FindBin::libs;

use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::OperatorPreference',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                operator_id
                pref_channel_id
                default_home_page
                packing_station_name
                printer_station_name
                packing_printer
            ]
        ],

        relations => [
            qw[
                pref_channel
                operator
                authorisation_sub_section
                channel
                default_home_page_sub_section
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
