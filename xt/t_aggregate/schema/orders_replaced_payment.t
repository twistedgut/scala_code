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
        moniker   => 'Orders::ReplacedPayment',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                orders_id
                psp_ref
                preauth_ref
                settle_ref
                fulfilled
                valid
                payment_method_id
                date_replaced
            ]
        ],

        relations => [
            qw[
                orders
                payment_method
                log_replaced_payment_fulfilled_changes
                log_replaced_payment_preauth_cancellations
                log_replaced_payment_valid_changes
            ]
        ],

        custom => [
            qw[
                payment_method_name
            ]
        ],

        resultsets => [
            qw[
                order_by_id
                order_by_id_desc
            ]
        ],
    }
);

$schematest->run_tests();
