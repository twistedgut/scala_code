#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::MessageQueue;
use Test::XTracker::Data;
use XTracker::Config::Local 'config_var';

my $amq = Test::XTracker::MessageQueue->new;

my $payload = {
    products => [
        {
            product_id => 1,
            channel_id => 1,
        },
        {
            product_id => 2,
            channel_id => 1,
        },
    ],
    fields => {
        foo => "bar",
    },
};

my $destination = config_var('Producer::ProductService::MassSetField','destination');

$amq->clear_destination($destination);

lives_ok {
    $amq->transform_and_send(
        'XT::DC::Messaging::Producer::ProductService::MassSetField',
        $payload
    )
} "Can send valid message";

$amq->assert_messages({
    destination => $destination,
    assert_header => superhashof({
        type => 'mass_set_field',
    }),
    assert_body => superhashof({
        products => $payload->{products},
        fields   => $payload->{fields}
    }),
},"message matches");

done_testing;
