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
        moniker   => 'Orders::LogPaymentPreauthCancellation',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                orders_payment_id
                cancelled
                preauth_ref_cancelled
                context
                message
                date
                operator_id
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
                get_preauth_cancelled_success
                get_preauth_cancelled_failure
                get_preauth_cancelled_attempts
                move_to_replaced_payment_log_and_delete
            ]
        ],
    }
);

$schematest->run_tests();
