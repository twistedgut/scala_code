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
        moniker   => 'Public::PurchaseOrderType',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                type
            ]
        ],

        relations => [
            qw[
                purchase_orders
                super_purchase_orders
                voucher_purchase_orders
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                drop_down_options
                po_types
            ]
        ],
    }
);

$schematest->run_tests();
