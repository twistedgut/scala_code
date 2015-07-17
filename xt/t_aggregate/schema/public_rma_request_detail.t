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
        moniker   => 'Public::RmaRequestDetail',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                rma_request_id
                rtv_quantity_id
                delivery_item_id
                variant_id
                quantity
                fault_type_id
                fault_description
                type_id
                status_id
            ]
        ],

        relations => [
            qw[
                rma_request
                variant
                rma_request_detail_status_logs
                delivery_item
                rtv_shipment_details
                fault_type
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
