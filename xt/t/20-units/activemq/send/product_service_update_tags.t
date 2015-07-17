#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::RunCondition
    iws_phase=> 'all',
    dc       => 'all',
    database => 'all';
use Test::XTracker::MessageQueue;
use Test::XTracker::Data;
use XTracker::Config::Local 'config_var';

my $amq = Test::XTracker::MessageQueue->new;

my($channel,$pids) =
           Test::XTracker::Data->grab_products({how_many => 10});

my $data;
$data->{channel_id}       = $channel->id;
@{$data->{pids}}          = map { $_->{pid} } @{$pids};
$data->{add_product_tags} = ['foo'];
$data->{remove_product_tags} = ['bar'];

my $destination = config_var('Producer::ProductService::UpdateProductTags','destination');

$amq->clear_destination($destination);

lives_ok {
    $amq->transform_and_send(
        'XT::DC::Messaging::Producer::ProductService::UpdateProductTags', $data
    )
} "Can send valid message";

my @products;
foreach ( @{$pids} ) {
    push @products, {
        product_id => $_->{pid},
        channel_id => $channel->id,
    };
}

$amq->assert_messages({
    destination => $destination,
    assert_header => superhashof({
        type => 'update_product_tags',
    }),
    assert_body => superhashof({
        products => bag(@products),
        add_product_tags => $data->{add_product_tags},
        remove_product_tags => $data->{remove_product_tags},
    }),
},"message matches");

done_testing;
