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
        moniker   => 'Voucher::Code',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                voucher_product_id
                stock_order_item_id
                code
                assigned
                created
                expiry_date
                source
                send_reminder_email
            ]
        ],

        relations => [
            qw[
                voucher_product
                stock_order_item
                credit_logs
                shipment_items
                tenders
            ]
        ],

        custom => [
            qw[
                activate
                is_active
                subtract_credit
                remaining_credit
                assigned_code
                order
                deactivate_code
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
