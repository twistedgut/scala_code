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
        moniker   => 'Public::PreOrderItem',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                pre_order_id
                variant_id
                reservation_id
                pre_order_item_status_id
                tax
                duty
                unit_price
                created
                original_unit_price
                original_tax
                original_duty
                last_updated
            ]
        ],

        relations => [
            qw[
                pre_order
                pre_order_item_status
                pre_order_item_status_logs
                pre_order_refund_items
                reservation
                variant
                unique_complete_pre_order_item_status_logs
            ]
        ],

        custom => [
            qw[
                is_selected
                is_complete
                is_exported
                is_cancelled
                is_payment_declined
                is_confirmed
                is_confirmable
                can_be_cancelled
                update_status
                cancel
                update_reservation_id
                channel
                product_details_for_email
            ]
        ],

        resultsets => [
            qw[
                available_to_cancel
                not_notifiable
                status_log_for_summary_page
                selected
                confirmed
                payment_declined
                complete
                exported
                cancelled
                not_selected
                not_confirmed
                not_payment_declined
                not_complete
                not_exported
                not_cancelled
                are_all_selected
                are_all_confirmed
                are_all_payment_declined
                are_all_complete
                are_all_exported
                are_all_cancelled
                are_all_confirmable
                update_status
                order_by_id
                order_by_id_desc
                total_value
                total_original_value
            ]
        ],
    }
);

$schematest->run_tests();
