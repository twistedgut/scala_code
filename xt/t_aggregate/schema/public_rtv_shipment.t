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
        moniker   => 'Public::RTVShipment',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                designer_rtv_carrier_id
                designer_rtv_address_id
                date_time
                status_id
                airway_bill
                channel_id
            ]
        ],

        relations => [
            qw[
                status
                rtv_shipment_status_log
                rtv_shipment_status_logs
                rtv_shipment_details
                channel
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                rtv_packing_summary
            ]
        ],
    }
);

$schematest->run_tests();
