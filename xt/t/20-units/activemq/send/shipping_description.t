#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::Data::Shipping;
use Test::XTracker::RunCondition
    dc         => ['DC1','DC2'];

my $sender = Test::XTracker::MessageQueue->new();
my $ship_desc = Test::XTracker::Data::Shipping->grab_shipping_description();

subtest 'validation' => sub {

    throws_ok { $sender->transform_and_send('XT::DC::Messaging::Producer::Shipping::Description') }
        qr/Missing shipping_description argument/, 'Missing argument caught okay';

    throws_ok { $sender->transform_and_send('XT::DC::Messaging::Producer::Shipping::Description',{
        shipping_description=>$ship_desc->shipping_charge
    }) } qr/Expects a Shipping::Description object/, 'Wrong object caught okay';

    lives_ok { $sender->transform_and_send('XT::DC::Messaging::Producer::Shipping::Description',{
        shipping_description=>$ship_desc }) } 'Lives with correct args';

};

subtest 'broadcast' => sub {
    $sender->clear_destination('/topic/product_info');

    $sender->transform_and_send('XT::DC::Messaging::Producer::Shipping::Description',{shipping_description=>$ship_desc});

    $sender->assert_messages({
        destination => '/topic/product_info',
        assert_header => superhashof({
            type => 'ShippingDescription',
        }),
        assert_body => superhashof({
            name => $ship_desc->name,
            public_name => $ship_desc->public_name,
            title => $ship_desc->title,
            public_title => $ship_desc->public_title,
            product_id => $ship_desc->shipping_charge->product_id(),
            size_id => $ship_desc->shipping_charge->size_id(),
            default_price => $ship_desc->shipping_charge->charge,
            default_currency => $ship_desc->shipping_charge->currency->currency,
            sku => $ship_desc->shipping_charge->sku,
            short_delivery_description => $ship_desc->short_delivery_description,
            long_delivery_description => $ship_desc->long_delivery_description,
            estimated_delivery => $ship_desc->estimated_delivery,
            delivery_confirmation => $ship_desc->delivery_confirmation,
        }),
    });

};

subtest 'with country override' => sub {
    my $sd = Test::XTracker::Data::Shipping
        ->grab_shipping_description({ country_override => 1 });

    $sender->clear_destination('/topic/product_info');

    $sender->transform_and_send('XT::DC::Messaging::Producer::Shipping::Description',{ shipping_description => $sd });

    $sender->assert_messages({
        destination => '/topic/product_info',
        assert_header => superhashof({
            type => 'ShippingDescription',
        }),
        assert_body => superhashof({
            sku => $sd->shipping_charge->sku,
            country_charges => ignore(),
        }),
    });

};

subtest 'with region override' => sub {
    my $sd = Test::XTracker::Data::Shipping
        ->grab_shipping_description({ region_override => 1 });

    $sender->clear_destination('/topic/product_info');

    $sender->transform_and_send('XT::DC::Messaging::Producer::Shipping::Description',{ shipping_description => $sd });

    $sender->assert_messages({
        destination => '/topic/product_info',
        assert_header => superhashof({
            type => 'ShippingDescription',
        }),
        assert_body => superhashof({
            sku => $sd->shipping_charge->sku,
            region_charges => ignore(),
        }),
    });

};

done_testing();
