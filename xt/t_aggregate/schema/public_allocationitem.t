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
        moniker   => 'Public::AllocationItem',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                status_id
                shipment_item_id
                allocation_id
                picked_at
                picked_by
                picked_into
                delivered_at
                actual_prl_delivery_destination_id
                delivery_order
            ]
        ],

        relations => [
            qw[
                allocation
                shipment_item
                status
                allocation_item_logs
                actual_prl_delivery_destination
                integration_container_items
            ]
        ],

        custom => [
            qw[
                variant_or_voucher_variant
                is_active
                is_allocated
                is_picked
                is_picking
                is_short_picked
            ]
        ],

        resultsets => [
            qw[
                filter_active
                distinct_container_ids
            ]
        ],
    }
);

$schematest->run_tests();
