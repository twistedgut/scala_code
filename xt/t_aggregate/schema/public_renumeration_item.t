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
        moniker   => 'Public::RenumerationItem',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                renumeration_id
                shipment_item_id
                unit_price
                tax
                duty
                last_updated
            ]
        ],

        relations => [
            qw[
                shipment_item
                renumeration
            ]
        ],

        custom => [
            qw[
                format_as_refund_line_item
                total_price
            ]
        ],

        resultsets => [
            qw[
                find_by_shipment_item
                order_by_id
            ]
        ],
    }
);

$schematest->run_tests();
