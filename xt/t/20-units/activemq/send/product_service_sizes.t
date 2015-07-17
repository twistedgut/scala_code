#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::MessageQueue;
use Test::XTracker::Data;
use XTracker::Config::Local 'config_var';

my $amq = Test::XTracker::MessageQueue->new;

my($channel,$pids) =
           Test::XTracker::Data->grab_products({how_many => 1});

my $data;
$data->{channel_id} = $channel->id;
$data->{product}    = my $product = $pids->[0]{product};

my $destination = config_var('Producer::ProductService::Sizing','destination');

$amq->clear_destination($destination);

lives_ok {
    $amq->transform_and_send(
        'XT::DC::Messaging::Producer::ProductService::Sizing', $data
    )
} "Can send valid message";

my @variants = map {
    superhashof({
        variant_id => $_->id,
        size_id => $_->size_id,
        position => $_->size->size_scheme_variant_size_size_ids->single({
            size_scheme_id => $_->product->product_attribute->size_scheme_id,
        })->position
    })
} $product->variants;

$amq->assert_messages({
    destination => $destination,
    assert_header => superhashof({
        type => 'product_sizes',
    }),
    assert_body => superhashof({
        product_id => $pids->[0]{pid},
        channel_id => $channel->id,
        size_scheme_variant_size => bag(@variants),
    }),
},"message matches");

done_testing;
