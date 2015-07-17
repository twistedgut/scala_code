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
        moniker   => 'Public::RTVQuantity',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                variant_id
                location_id
                quantity
                delivery_item_id
                fault_type_id
                fault_description
                origin
                date_created
                channel_id
                status_id
            ]
        ],

        relations => [
            qw[
                delivery_item
                item_fault_type
                location
                variant
                rtv_inspection_pick_request_details
                rma_request_detail
                status
                channel
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
