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
        moniker   => 'Public::Allocation',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                shipment_id
                prl_id
                status_id
                pick_sent
                prl_delivery_destination_id
            ]
        ],

        relations => [
            qw[
                allocation_items
                prl_delivery_destination
                shipment
                status
                prl
            ]
        ],

        custom => [
            qw[
                prl_location
                pick_complete
                picking_mix_group
                is_allocated
                is_staged
                is_picked
                is_picking
                pick
                distinct_container_ids
            ]
        ],

        resultsets => [
            qw[
                pre_picking
                with_active_items
                allocated
                dms
                allocated_dms_only
                pick_triggered_by_sibling_allocations
                with_siblings_in_prl_with_staging_area
                with_siblings_in_status
                with_siblings_with_items_in_status
                allocations_picking_summary
            ]
        ],
    }
);

$schematest->run_tests();
