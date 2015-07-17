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
        moniker   => 'Public::PurchaseOrder',
        glue      => 'Result',
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
                comment
                designer_id
                description
                season_id
                act_id
                confirmed
                confirmed_operator_id
                placed_by
                when_confirmed
            ]
        ],

        relations => [
            qw[
                act
                currency
                type
                season
                status
                channel
                designer
                stock_orders
                is_not_editable_in_fulcrum
                confirmed_operator
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
