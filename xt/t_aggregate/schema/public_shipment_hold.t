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
        moniker   => 'Public::ShipmentHold',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                shipment_id
                shipment_hold_reason_id
                operator_id
                comment
                hold_date
                release_date
            ]
        ],

        relations => [
            qw[
                shipment_hold_reason
                shipment
                operator
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                order_by_id
                order_by_id_desc
                order_by_hold_date
                order_by_hold_date_desc
            ]
        ],
    }
);

$schematest->run_tests();
