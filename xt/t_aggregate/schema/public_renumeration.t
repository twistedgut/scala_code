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
        moniker   => 'Public::Renumeration',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                shipment_id
                invoice_nr
                renumeration_type_id
                renumeration_class_id
                renumeration_status_id
                shipping
                misc_refund
                alt_customer_nr
                gift_credit
                store_credit
                currency_id
                sent_to_psp
                gift_voucher
                renumeration_reason_id
                last_updated
            ]
        ],

        relations => [
            qw[
                link_return_renumerations
                shipment
                renumeration_class
                renumeration_type
                currency
                renumeration_status
                renumeration_change_logs
                renumeration_items
                renumeration_status_logs
                renumeration_tenders
                link_return_renumeration
                renumeration_reason
                card_refund
            ]
        ],

        custom => [
            qw[
                return
                is_cancelled
                is_completed
                is_printed
                is_pending
                update_status
                split_me
                completion_date
                total_value
                grand_total
                simple_sum_total_of_invoice
                generate_invoice
                get_invoice_date
                is_card_refund
                is_store_credit
                refund_to_customer
                check_rma_not_cancelled
                is_awaiting_authorisation
                for_return
                for_gratuity
                get_reason_for_display
                format_shipping_as_refund_line_item
                format_items_for_refund
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
                card_debit_type
                not_cancelled
                not_yet_complete
                modifiable
                for_returns
                for_not_orders
                previous_shipping_refund
                cancel_for_returns
            ]
        ],
    }
);

$schematest->run_tests();
