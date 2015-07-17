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
        moniker   => 'Public::Container',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                status_id
                place
                pack_lane_id
                routed_at
                arrived_at
                has_arrived
                physical_place_id
            ]
        ],

        relations => [
            qw[
                status
                orphan_items
                shipment_items
                putaway_prep_containers
                pack_lane
                physical_place
                integration_containers
            ]
        ],

        custom => [
            qw[
                is_in_commissioner
                validate_pick_into
                validate_packing_exception_into
                validate_orphan_item_into
                set_status
                add_picked_item
                add_packing_exception_item
                add_orphan_item
                add_picked_shipment
                remove_shipment
                remove_item
                is_empty
                is_full
                shipment_ids
                shipments
                is_multi_shipment
                get_channel
                physical_type
                accepts_faulty_items
                accepts_putaway_ok_items
                set_place
                send_to_commissioner
                remove_from_commissioner
                are_all_items_cancel_pending
                are_all_shipments_cancelled
                are_all_shipments_on_hold
                packing_ready_in_commissioner
                contains_orphan_items
            ]
        ],

        resultsets => [
            qw[
                contains_packable
                in_commissioner
                send_to_commissioner
            ]
        ],
    }
);

$schematest->run_tests();
