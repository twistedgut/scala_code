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
        moniker   => 'Public::PreOrderNote',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                pre_order_id
                note
                note_type_id
                operator_id
                date
            ]
        ],

        relations => [
            qw[
                pre_order
                note_type
                operator
            ]
        ],

        custom => [
            qw[
                  is_shipment_address_change
                  is_misc
                  is_online_fraud_finance
                  is_pre_order_item
            ]
        ],

        resultsets => [
            qw[
                shipment_address_change
                misc
                online_fraud_finance
                pre_order_item
                not_shipment_address_change
                not_misc
                not_online_fraud_finance
                not_pre_order_item
                are_all_shipment_address_change
                are_all_misc
                are_all_online_fraud_finance
                are_all_pre_order_item
                order_by_id
                order_by_id_desc
                order_by_date
                order_by_date_desc
                for_operator_id
            ]
        ],
    }
);

$schematest->run_tests();
