#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::MessageQueue;
use Test::XTracker::Data;
use XTracker::Config::Local 'config_var';

my $amq = Test::XTracker::MessageQueue->new;

my($channel,$pids) =
           Test::XTracker::Data->grab_products({how_many => 1});

my $product    = $pids->[0]->{product};
my $product_id = $product->id;
my $channel_id = $product->product_channel->first->channel_id;

subtest 'validation' => sub {
    my $msg = { product_id => $product_id, channel_id => $channel_id };

    my $product_id = delete $msg->{product_id};
    dies_ok { $amq->transform_and_send( 'XT::DC::Messaging::Producer::Product::Notify', $msg ) } "Cant send invalid message";

    $msg->{product_id} = $product_id;
    lives_ok { $amq->transform_and_send( 'XT::DC::Messaging::Producer::Product::Notify', $msg ) } "Can send valid message";

    $msg->{voucher_id} = 12345;
    dies_ok { $amq->transform_and_send( 'XT::DC::Messaging::Producer::Product::Notify', $msg ) } "Cant send invalid message";

    delete $msg->{product_id};
    lives_ok { $amq->transform_and_send( 'XT::DC::Messaging::Producer::Product::Notify', $msg ) } "Can send valid message";
};

subtest 'message content' => sub {
    my $msg = { product_id => $product_id, channel_id => $channel_id };
    my $destination = config_var('Producer::Product::Notify', 'destination');

    $amq->clear_destination($destination);

    $amq->transform_and_send( 'XT::DC::Messaging::Producer::Product::Notify', $msg );

    $amq->assert_messages({
        destination => $destination,
        assert_header => superhashof({
            type => 'product_data_request',
        }),
        assert_body => superhashof({
            product_id => $product_id,
            channel_id => $channel_id,
        }),
    },"message matches");

};

done_testing;
