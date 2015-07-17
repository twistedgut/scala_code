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
        moniker   => 'Public::SuperPurchaseOrder',
        glue      => 'Result',

        # *** DO NOT COPY THIS INTO ANY OTHER TEST FILES ***
        # this is needed until we resolve a problem with the inheritence
        # giving things different columns and relationships
        fail_on_missing => 0,
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                purchase_order_number
                date
                currency_id
                status_id
                exchange_rate
                cancel
                supplier_id
                channel_id
                type_id
            ]
        ],

        relations => [
            qw[
                status
                channel
                type
                currency
                stock_orders
                season
                currency
            ]
        ],

        custom => [
            qw[
                is_cancelled
                check_status
                update_status
                stock_orders_by_pid
                is_product_po
                is_voucher_po
                quantity_ordered
                originally_ordered
                quantity_delivered
                cancel_po
            ]
        ],

        resultsets => [
            qw[
                incomplete
                stock_in_search
            ]
        ],
    }
);

$schematest->run_tests();
