#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 CANDO-47: New PSP Cancel method

This tests that the class 'XT::Domain::Payment' has all of the expected
methods, including the new 'cancel_preauth' method.

This Class speaks to the PSP service to settle payments, refunds & get the payment
information that is shown on the Order View page.

=cut


use Test::XTracker::Data;

use_ok( 'XT::Domain::Payment' );

my $payment = XT::Domain::Payment->new();
isa_ok( $payment, 'XT::Domain::Payment' );

# check all these methods 'can' be called
my @methods = ( qw(
        amount_exceeds_provider_threshold
        cancel_preauth
        create_new_payment_session
        get_card_details_status
        get_new_card_token
        getcustomer_saved_cards
        getinfo_payment
        getorder_numbers
        init_with_payment_session
        payment_form
        preauth_with_payment_session
        reauthorise_address
        refund_payment
        save_card
        settle_payment
        shift_dp
        translate_error_code
        get_refund_information
        payment_amendment
        payment_replacement
    ) );
foreach my $method ( @methods ) {
    ok( $payment->can( $method ), "XT::Domain::Payment Can: '$method'" );
}

done_testing;
