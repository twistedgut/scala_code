#!/usr/bin/env perl

use NAP::policy     qw( test );

=head1 NAME

psp_default.t

=head1 DESCRIPTION

Tests the Defaults used for certain PSP functionality and that the minimum
expected Payment Methods and Third Party Status mapping is present in the DB.

=cut

use Test::XTracker::Data;

use XTracker::Constants             qw( :psp_default );
use XTracker::Constants::FromDB     qw( :orders_payment_method_class :orders_internal_third_party_status );


my $schema  = Test::XTracker::Data->get_schema;

my $payment_method_rs = $schema->resultset('Orders::PaymentMethod');

note "Check Default Payment Method exists in 'orders.payment_method'";
my $method_rec = $payment_method_rs
                            ->find( {
    payment_method => $PSP_DEFAULT_PAYMENT_METHOD,
} );
isa_ok( $method_rec, 'XTracker::Schema::Result::Orders::PaymentMethod',
                "found an 'orders.payment_method' record for the Default" );
is( $method_rec->payment_method, $PSP_DEFAULT_PAYMENT_METHOD,
                "and is as Expected: '${PSP_DEFAULT_PAYMENT_METHOD}'" );


# anonymous function to return a list of fields
# and their values so that they can be checked
my $_get_fields_to_test = sub {
    my $rec = shift;

    # list of fields on the 'orders.payment_method'
    # table to check the values of, in the tests below
    my @fields_to_check = qw(
        notify_psp_of_address_change
        billing_and_shipping_address_always_the_same
        allow_full_refund_using_only_store_credit
        allow_full_refund_using_only_payment
        produce_customer_invoice_at_fulfilment
        allow_editing_of_shipping_address_after_settlement
        allow_goodwill_refund_using_payment
        cancel_payment_after_force_address_update
    );

    return map { $_ => $rec->$_ } @fields_to_check;
};


note "Check for minimum Expected Payment Methods in 'orders.payment_method' table & Third Party Status Mappings";
my %expect_payment_methods = (
    'Credit Card'   => {
        class => $ORDERS_PAYMENT_METHOD_CLASS__CARD,
        third_party_status_maps => {},

        # boolean fields on the 'payment_method' table
        notify_psp_of_address_change                 => 0,
        billing_and_shipping_address_always_the_same => 0,
        allow_full_refund_using_only_store_credit    => 1,
        allow_full_refund_using_only_payment         => 1,
        produce_customer_invoice_at_fulfilment       => 1,
        allow_editing_of_shipping_address_after_settlement =>1,
        allow_goodwill_refund_using_payment          => 1,
        cancel_payment_after_force_address_update    => 0,
    },
    'PayPal'        => {
        class => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
        third_party_status_maps => {
            $ORDERS_INTERNAL_THIRD_PARTY_STATUS__PENDING  => 'PENDING',
            $ORDERS_INTERNAL_THIRD_PARTY_STATUS__ACCEPTED => 'ACCEPTED',
            $ORDERS_INTERNAL_THIRD_PARTY_STATUS__REJECTED => 'REJECTED',
        },
        notify_psp_of_address_change                 => 1,
        billing_and_shipping_address_always_the_same => 0,
        allow_full_refund_using_only_store_credit    => 1,
        allow_full_refund_using_only_payment         => 1,
        produce_customer_invoice_at_fulfilment       => 1,
        allow_editing_of_shipping_address_after_settlement =>1,
        allow_goodwill_refund_using_payment          => 1,
        cancel_payment_after_force_address_update    => 0,
    },
    'Klarna'        => {
        class => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
        third_party_status_maps => {
            $ORDERS_INTERNAL_THIRD_PARTY_STATUS__PENDING  => 'PENDING',
            $ORDERS_INTERNAL_THIRD_PARTY_STATUS__ACCEPTED => 'ACCEPTED',
            $ORDERS_INTERNAL_THIRD_PARTY_STATUS__REJECTED => 'REJECTED',
        },
        notify_psp_of_address_change                 => 1,
        billing_and_shipping_address_always_the_same => 1,
        allow_full_refund_using_only_store_credit    => 0,
        allow_full_refund_using_only_payment         => 0,
        produce_customer_invoice_at_fulfilment       => 0,
        allow_editing_of_shipping_address_after_settlement => 0,
        allow_goodwill_refund_using_payment          => 0,
        cancel_payment_after_force_address_update    => 1,
    },
);
my %got_payment_methods =
    map {
        $_->payment_method => {
            class   => $_->payment_method_class_id,
            third_party_status_maps => {
                map {
                    $_->internal_status_id => $_->third_party_status
                } $_->third_party_payment_method_status_maps->all
            },
            $_get_fields_to_test->( $_ ),
        },
    } $payment_method_rs->all;
cmp_deeply( \%got_payment_methods, superhashof( \%expect_payment_methods ),
                "got the Expected Payment Methods in 'orders.payment_method'" );


done_testing;

