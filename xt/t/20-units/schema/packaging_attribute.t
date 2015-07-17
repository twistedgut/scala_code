#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::Data::Packaging;
use Test::XTracker::RunCondition
    dc         => ['DC1','DC2'];


my $sender = Test::XTracker::MessageQueue->new();
my $pa;

subtest 'broadcast' => sub {
    $sender->clear_destination('/topic/product_info');

    # grab shipping_description
    $pa = Test::XTracker::Data::Packaging->grab_packaging_attribute;

    isa_ok( $pa, 'XTracker::Schema::Result::Public::PackagingAttribute',
        'Grabbed packaging attribute object' );

    # call the broadcast method
    $pa->broadcast();

    # did it broadcast?
    $sender->assert_messages({
        destination => '/topic/product_info',
        assert_count => 1,
    }, 'Broadcast sent' );

};

subtest 'attributes' => sub {
    my ( $product_id, $size_id ) = split /-/, $pa->packaging_type->sku;

    is( $pa->product_id, $product_id+0, 'Product ID returned' );

    is( $pa->size_id, $size_id+0, 'Size ID returned' );

    is( $pa->sku, $pa->packaging_type->sku, 'SKU returned' );

    is( $pa->type, $pa->packaging_type->name, 'Type returned' );
};

done_testing();
