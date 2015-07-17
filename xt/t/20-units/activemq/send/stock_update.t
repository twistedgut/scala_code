#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local         qw( config_var );

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema' );

my $amq = Test::XTracker::MessageQueue->new({schema=>$schema});
isa_ok( $amq, 'Test::XTracker::MessageQueue' );

# get local NAP channel to get local queue name
my $channel = Test::XTracker::Data->get_local_channel();
my $queue = '/queue/'.$channel->lc_web_name.'-stock.update';
my $channel_id = $channel->id;
note "Using Queue: $queue";

#
# test normal products
#
note "Testing Normal Products";
$amq->clear_destination($queue);
my $pids    = Test::XTracker::Data->grab_products( {
    how_many => 1,
    channel_id => $channel_id,
} );
lives_ok{
    $amq->transform_and_send( 'XT::DC::Messaging::Producer::Stock::Update', {
                        sku => $pids->[0]{sku},
                        channel_id => $channel_id,
                        quantity_change => 5,
                    } );
} "Send update using SKU";
$amq->assert_messages( {
    destination => $queue,
    assert_header => superhashof({
        type => 'StockUpdate',
    }),
    assert_body => superhashof({
        sku => $pids->[0]{sku},
        quantity_change => 5,
    }),
}, 'Message found for correct SKU & Quantity' );
$amq->clear_destination($queue);
lives_ok{
    $amq->transform_and_send( 'XT::DC::Messaging::Producer::Stock::Update', {
                        dc_variant_id => $pids->[0]{variant_id},
                        channel_id => $channel_id,
                        quantity_change => 7,
                    } );
} "Send update using Variant Id";
$amq->assert_messages( {
    destination => $queue,
    assert_header => superhashof({
        type => 'StockUpdate',
    }),
    assert_body => superhashof({
        sku => $pids->[0]{sku},
        quantity_change => 7,
    }),
}, 'Message found for correct SKU & Quantity' );

#
# test voucher products
#
note "Testing Voucher Products";
$amq->clear_destination($queue);
my $voucher = Test::XTracker::Data->create_voucher();
lives_ok{
    $amq->transform_and_send( 'XT::DC::Messaging::Producer::Stock::Update', {
                        sku => $voucher->variant->sku,
                        channel_id => $channel_id,
                        quantity_change => 2,
                    } );
} "Send update using SKU";
$amq->assert_messages( {
    destination => $queue,
    assert_header => superhashof({
        type => 'StockUpdate',
    }),
    assert_body => superhashof({
        sku => $voucher->variant->sku,
        quantity_change => 2,
    }),
}, 'Message found for correct SKU & Quantity' );
$amq->clear_destination($queue);
lives_ok{
    $amq->transform_and_send( 'XT::DC::Messaging::Producer::Stock::Update', {
                        dc_variant_id => $voucher->variant->id,
                        channel_id => $channel_id,
                        quantity_change => -4,
                    } );
} "Send update using Variant Id";
$amq->assert_messages( {
    destination => $queue,
    assert_header => superhashof({
        type => 'StockUpdate',
    }),
    assert_body => superhashof({
        sku => $voucher->variant->sku,
        quantity_change => -4,
    }),
}, 'Message found for correct SKU & Quantity' );

# test '+3' goes to the web-site as '3'
$amq->clear_destination($queue);
lives_ok{
    $amq->transform_and_send( 'XT::DC::Messaging::Producer::Stock::Update', {
                        dc_variant_id => $voucher->variant->id,
                        channel_id => $channel_id,
                        quantity_change => '+3',
                    } );
} "Send update using with leading '+'";
$amq->assert_messages( {
    destination => $queue,
    assert_header => superhashof({
        type => 'StockUpdate',
    }),
    assert_body => superhashof({
        sku => $voucher->variant->sku,
        quantity_change => 3,
    }),
}, "Message found and Quantity has lost leading '+'" );
# test again with 2 digits because I'm paranoid
$amq->clear_destination($queue);
lives_ok{
    $amq->transform_and_send( 'XT::DC::Messaging::Producer::Stock::Update', {
                        dc_variant_id => $voucher->variant->id,
                        channel_id => $channel_id,
                        quantity_change => '++42+',
                    } );
} "Send update using with leading & trail;ing '+' and 2 digit stock update";
$amq->assert_messages( {
    destination => $queue,
    assert_header => superhashof({
        type => 'StockUpdate',
    }),
    assert_body => superhashof({
        sku => $voucher->variant->sku,
        quantity_change => 42,
    }),
}, "Message found and Quantity has lost leading '+' and 2 digit stock update" );

#
# test dies with non-existent variant id
#
note "Testing Non-Existing Variant";
$amq->clear_destination($queue);
dies_ok{
    $amq->transform_and_send( 'XT::DC::Messaging::Producer::Stock::Update', {
                        dc_variant_id => -456,
                        channel_id => $channel_id,
                        quantity_change => 12,
                    } );
} "Update should die using Non-Existent Variant Id";

done_testing;
