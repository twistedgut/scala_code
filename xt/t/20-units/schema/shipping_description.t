#!perl
use NAP::policy "tt", 'test';
use Test::XTracker::Data::Shipping;
use Test::XTracker::RunCondition
    iws_phase  => 'all',
    dc         => ['DC1','DC2'],
    database   => 'all';


subtest 'channel & business' => sub {
    my $sender = Test::XTracker::MessageQueue->new();
    my $shipping_description
        = Test::XTracker::Data::Shipping->grab_shipping_description();

    isa_ok($shipping_description->business(), 'XTracker::Schema::Result::Public::Business',
        'Correct link to business object');

    isa_ok($shipping_description->channel(), 'XTracker::Schema::Result::Public::Channel',
        'Correct link to channel object');

};

done_testing();
