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
        moniker   => 'Orders::LogPaymentFulfilledChange',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                payment_id
                new_state
                date_changed
                operator_id
                reason_for_change
            ]
        ],

        relations => [
            qw[
                payment
                operator
            ]
        ],

        custom => [
            qw[
                copy_to_replaced_payment_log
            ]
        ],

        resultsets => [
            qw[
                move_to_replaced_payment_log_and_delete
                get_all_payment_fulfilled_change_logs_for_order_id
                order_by_date_changed
                order_by_date_changed_desc
            ]
        ],
    }
);

$schematest->run_tests();
