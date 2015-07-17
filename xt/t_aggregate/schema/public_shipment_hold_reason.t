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
        moniker   => 'Public::ShipmentHoldReason',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                reason
                manually_releasable
                information
                allow_new_sla_on_release
            ]
        ],

        relations => [
            qw[
                shipment_holds
                shipment_hold_logs
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                get_reasons_for_hold_page
            ]
        ],
    }
);

$schematest->run_tests();
