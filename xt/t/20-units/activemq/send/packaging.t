#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data::Packaging;
use Test::XTracker::RunCondition dc         => ['DC1','DC2'];

my $sender = Test::XTracker::MessageQueue->new();
my $pa = Test::XTracker::Data::Packaging->grab_packaging_attribute();

subtest 'validation' => sub {

    throws_ok { $sender->transform_and_send('XT::DC::Messaging::Producer::Packaging') }
        qr/Missing packaging_attribute argument/, 'Missing argument caught okay';

    throws_ok { $sender->transform_and_send('XT::DC::Messaging::Producer::Packaging',{
        packaging_attribute => $pa->packaging_type
    }) } qr/Expects a Public::PackagingAttribute object/, 'Wrong object caught okay';

    lives_ok { $sender->transform_and_send('XT::DC::Messaging::Producer::Packaging',{
        packaging_attribute => $pa }) } 'Lives with correct args';

};

subtest 'broadcast' => sub {
    $sender->clear_destination('/topic/product_info');

    $sender->transform_and_send('XT::DC::Messaging::Producer::Packaging',{packaging_attribute=>$pa});

    $sender->assert_messages({
        destination => '/topic/product_info',
        assert_header => superhashof({
            type => 'PackagingMessage',
        }),
        assert_body => superhashof({
            name => $pa->name,
            public_name => $pa->public_name,
            title => $pa->title,
            public_title => $pa->public_title,
            type => $pa->type,
            product_id => $pa->product_id(),
            size_id => $pa->size_id(),
            sku => $pa->sku,
            description => $pa->description,
        }),
    });

};

done_testing();
