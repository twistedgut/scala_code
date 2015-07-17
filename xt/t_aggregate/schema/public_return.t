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
        moniker   => 'Public::Return',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                shipment_id
                rma_number
                return_status_id
                comment
                exchange_shipment_id
                pickup
                creation_date
                expiry_date
                cancellation_date
                last_updated
            ]
        ],

        relations => [
            qw[
                link_delivery__returns
                link_return_renumerations
                link_routing_export__returns
                shipment
                return_status
                return_items
                return_notes
                link_return_renumeration
                return_status_logs
                link_order__shipment
                exchange_shipment
                renumerations
                routing_schedules
                link_routing_schedule__returns
                return_email_logs
                link_sms_correspondence__returns
                deliveries
            ]
        ],

        custom => [
            qw[
                is_cancelled
                set_lost
                set_awaiting_return
                set_complete
                is_lost
                update_status
                logs
                item_logs
                split_if_needed
                check_complete
                return_item_from_shipment_item
                send_routing_schedule_notification
                can_use_csm
                csm_prefs_allow_method
                get_correspondence_logs
            ],
            # from Role 'Schema::Role::CustomerHierarchy'
            qw[
                next_in_hierarchy
                next_in_hierarchy_isa
                next_in_hierarchy_from_class
                next_in_hierarchy_with_method
            ]
        ],

        resultsets => [
            qw[
                not_cancelled
            ]
        ],
    }
);

$schematest->run_tests();
