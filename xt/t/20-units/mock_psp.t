#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::Data;
use Test::XTracker::RunCondition  export => [qw( $distribution_centre )];

# this gives us XT::Domain::Payment with our injected method
use Test::XTracker::Mock::PSP;


use Test::Most;
use base 'Test::Class';

sub startup : Test(startup => 1) {
    my ($self) = @_;

    # create a new XT::Domain::Payment
    # ** not Test::XT::Domain::Payment **

    $self->{mock_psp} = XT::Domain::Payment->new();
    isa_ok($self->{mock_psp}, 'XT::Domain::Payment');
}

sub test_mock_psp :Tests() {
    my ($self) = @_;

    my $payment_info;

    # make a call to get the data
    lives_ok {
        $payment_info = $self->{mock_psp}->getinfo_payment({
            reference => 'wibbly-woo',
        });
    } 'getinfo_payment() lives';

    # make sure the data looks like our injected data
    is($payment_info->{providerReference}, 'wibbly-woo', 'providerReference correct');
    is($payment_info->{cardInfo}{cardType}, 'DisasterCard', 'cardType correct');
}

Test::Class->runtests;

1;
