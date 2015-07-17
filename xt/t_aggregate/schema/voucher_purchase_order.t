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
        moniker   => 'Voucher::PurchaseOrder',
        glue      => 'Result',

        # *** DO NOT COPY THIS INTO ANY OTHER TEST FILES ***
        # this is needed until we resolve a problem with the table we inherit
        # from having a season relationship, that uses the child table's
        # season_id ... the problem is *we* don't have that column, only
        # public.purchase_order
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
                created_by
            ]
        ],

        relations => [
            qw[
                status
                channel
                type
                currency
                created_by
                stock_orders
            ]
        ],

        custom => [
            qw[
                is_cancelled
                check_status
                is_product_po
                quantity_ordered
                originally_ordered
                quantity_delivered
                cancel_po
                vouchers
                cancel_po
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
