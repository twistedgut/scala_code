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
        moniker   => 'Public::ReturnItem',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                return_id
                shipment_item_id
                return_item_status_id
                customer_issue_type_id
                return_type_id
                return_airway_bill
                variant_id
                creation_date
                exchange_shipment_item_id
                last_updated
            ]
        ],

        relations => [
            qw[
                shipment_item
                return
                customer_issue_type
                variant
                exchange_shipment_item
                status
                type
                variant
                return_item_status_logs
                link_delivery_item__return_items
                delivery_items
            ]
        ],

        custom => [
            qw[
                update_status
                reason
                status_str
                is_complete
                is_exchange
                is_refund
                is_awaiting_return
                is_booked_in
                is_failed_qc_awaiting_decision
                is_failed_qc_rejected
                is_failed_qc_accepted
                has_been_qced
                set_failed_qc_accepted
                set_failed_qc_rejected
                set_returned_to_customer
                accept_failed_qc
                incomplete_stock_process
                return_to_customer
                send_to_rtv_customer_repair
                reject_failed_qc
                is_cancelled
                uncancelled_delivery_item
                date_received
                exchange_ship_date
                refund_date
                is_passed_qc
                is_putaway_prep
                is_put_away
            ]
        ],

        resultsets => [
            qw[
                passed_qc
                failed_qc_awaiting_decision
                active_item_count
                by_shipment_item
                not_cancelled
                cancelled
                find_by_sku
                update_exchange_item_id
                beyond_qc_stage
            ]
        ],
    }
);

$schematest->run_tests();
