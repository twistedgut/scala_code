#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::MessageQueue;
use Test::XTracker::Data;
use XTracker::Config::Local 'config_var';

my $amq = Test::XTracker::MessageQueue->new;

my($channel,$pids) =
           Test::XTracker::Data->grab_products({how_many => 10});

my $data;
$data->{channel_id}       = $channel->id;
@{$data->{pids}}          = map { $_->{pid} } @{$pids};
$data->{upload_date}      = '2012-01-25T12:41:30Z';
$data->{upload_timestamp} = '2012-01-25T12:41:30Z';

my $destination = config_var('Producer::ProductService::Upload','destination');

$amq->clear_destination($destination);

lives_ok {
    $amq->transform_and_send(
        'XT::DC::Messaging::Producer::ProductService::Upload', $data
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
        type => 'promote_to_live',
    }),
    assert_body => superhashof({
        products => bag(@products),
    }),
},"message matches");

done_testing;
