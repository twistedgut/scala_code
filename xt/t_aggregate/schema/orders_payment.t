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
        moniker   => 'Orders::Payment',
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
                last_updated
            ]
        ],

        relations => [
            qw[
                orders
                log_payment_fulfilled_changes
                log_payment_preauth_cancellations
                log_payment_valid_changes
                payment_method
            ]
        ],

        custom => [
            qw[
                create
                check_fulfilled
                invalidate
                validate
                set_preauth_reference
                fulfill
                toggle_fulfilled_flag
                preauth_cancelled
                preauth_cancelled_failure
                preauth_cancelled_attempted
                psp_cancel_preauth
                psp_refund
                get_pspinfo
                method_is_credit_card
                method_is_third_party
                get_internal_third_party_status
                notify_psp_of_address_change_and_validate
                amount_exceeds_threshold
                copy_to_replacement_and_move_logs
            ]
        ],

        resultsets => [
            qw[
                get_payment_by_psp_ref
                invalidate
                validate
            ]
        ],
    }
);

$schematest->run_tests();
