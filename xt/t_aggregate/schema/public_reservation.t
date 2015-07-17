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
        moniker   => 'Public::Reservation',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                ordering_id
                variant_id
                customer_id
                operator_id
                date_created
                date_uploaded
                date_expired
                status_id
                notified
                date_advance_contact
                customer_note
                note
                channel_id
                reservation_source_id
                reservation_type_id
                last_updated
                commission_cut_off_date
            ]
        ],

        relations => [
            qw[
                channel
                status
                variant
                customer
                reservation_logs
                operator
                reservation_source
                reservation_type
                reservation_operator_logs
                pre_order_items
                link_shipment_item__reservations
                reservation_auto_change_logs
                link_shipment_item__reservation_by_pids
            ]
        ],

        custom => [
            qw[
                total_balance
                set_purchased
                upload_pending
                notify_of_auto_upload
                is_for_pre_order
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
                by_variant_id
                uploaded
                pending
                pending_in_priority_order
                auto_upload_pending
                not_for_pre_order
                commission_cut_off_date_from
                created_before_or_on
                cancelled_or_purchased
            ]
        ],
    }
);

$schematest->run_tests();
