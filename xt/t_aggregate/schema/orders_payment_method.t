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
        moniker   => 'Orders::PaymentMethod',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                payment_method
                payment_method_class_id
                string_from_psp
                notify_psp_of_address_change
                display_name
                billing_and_shipping_address_always_the_same
                notify_psp_of_basket_change
                allow_full_refund_using_only_store_credit
                allow_full_refund_using_only_payment
                produce_customer_invoice_at_fulfilment
                allow_editing_of_shipping_address_after_settlement
                display_name
                allow_goodwill_refund_using_payment
                cancel_payment_after_force_address_update
            ]
        ],

        relations => [
            qw[
                payment_method_class
                payments
                third_party_payment_method_status_maps
                replaced_payments
            ]
        ],

        custom => [
            qw[
                is_card
                is_third_party
                get_internal_third_party_status_for
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
