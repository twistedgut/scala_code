#!/usr/bin/env perl

use NAP::policy "tt", qw( test );

use HTTP::Response;

use XTracker::DBEncode qw( decode_it );
use XT::Net::PaymentService::Client;

# Redefine methods involved in processing the request to the PSP prior
# sending so that we can inspect the output from xtracker to the PSP
# $_[1]->content is the hashref containing the test data below.
# We're testing that the data being sent is what we expect.

no warnings "redefine";
*LWP::UserAgent::request
  = sub { return HTTP::Response->new(200, 'OK', undef, $_[1]->content) };
*XT::Net::PaymentService::Client::decode_json_content = sub { return $_[1] };
use warnings "redefine";

# The payment service client
my $psp = XT::Net::PaymentService::Client->new();

# Test data
my $test_data = {
    ascii       => {
        email       => 'nap@example.com',
        title       => 'Mr',
        firstName   => 'NAP',
        lastName    => 'Porter',
        address1    => 'WestGate',
        address2    => 'Ariel Way',
        address3    => 'Shepherds Bush',
        address4    => 'London',
        postcode    => 'W12 7GF',
    },
    chinese     => {
        email       => '我能吞@example.com',
        title       => 'Mr',
        firstName   => 'NAP',
        lastName    => 'Porter',
        address1    => '我能吞下玻璃而不傷身體。',
        address2    => '我能吞下玻璃而不傷身體。',
        address3    => 'Shepherds Bush',
        address4    => 'London',
        postcode    => 'W12 7GF',
    },
    french      => {
        email       => 'nap@example.com',
        title       => 'Mr',
        firstName   => 'NAP',
        lastName    => 'Bénéficiaire',
        address1    => 'Les naïfs ægithales',
        address2    => 'hâtifs pondant à Noël',
        address3    => 'où il gèle sont sûrs',
        address4    => "d'être déçus en voyant leurs drôles d'œufs abîmés",
        postcode    => 'W12 7GF',
    },
    german      => {
        email       => 'empfänger@example.com',
        title       => 'Mr',
        firstName   => 'NAP',
        lastName    => 'Jagdſchloß',
        address1    => 'Felsquellwaſſer patzte',
        address2    => 'kauzig-höfliche Bäcker',
        address3    => 'über ſeinem verſifften',
        address4    => 'London',
        postcode    => 'W12 7GF',
    },
};

my $payment_data = {
    cardNumber          => '1234123412341234',
    cardExpiryMonth     => '09',
    cardExpiryYear      => '10',
    cardCVSNumber       => '123',
    cardIssueNumber     => '1',
    currency            => 'GBP',
    coinAmount          => '45600',
    channel             => 'NAP-XT-INTL',
    distributionCentre  => 'NAP-DC1',
    paymentMethod       => 'CREDITCARD',
    isPreOrder          => 0,
    isSavedCard         => 0,
    merchantURL         => 'http://www.net-a-porter.com',
};

# Compare the request data at the last possible point before being sent to the
# PSP service against the input data defined in this test. It should match
while ( my ($test, $data) = each %$test_data ) {
    $data = decode_it($data);
    @$data{keys %$payment_data} = values %$payment_data;
    note($test);
    my $req = $psp->init_with_payment_session($data);
    ok($req, "init_with_payment_session returns ok");
    is_deeply(JSON->new->utf8->encode($data), $req, "$test data compares OK");
}

done_testing();
