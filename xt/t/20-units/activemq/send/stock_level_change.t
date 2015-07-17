#!/usr/bin/env perl
use NAP::policy "tt", 'test';


use Test::XTracker::MessageQueue;
use Test::Exception;
use XTracker::Config::Local qw/config_var/;
my $amq = Test::XTracker::MessageQueue->new;
my $schema  = Test::XTracker::Data->get_schema;
my $factory = $amq->producer;

isa_ok( $amq, 'Test::XTracker::MessageQueue' );
isa_ok( $schema, 'XTracker::Schema' );
isa_ok( $factory, 'Net::Stomp::Producer' );

my $channel_rs = $schema->resultset('Public::Channel');

# all channels, yes, we want to make sure we don't stend stuff to JC
my @channels = $channel_rs->get_channels_rs->all;

my $msg_type = 'XT::DC::Messaging::Producer::Stock::LevelChange';

CHANNEL:
foreach my $channel ( @channels ) {
    my $topic = config_var('Producer::Stock::LevelChange','routes_map')->{$channel->web_name};

    my $current = '47';
    my $delta   = '-4';
    my $sku     = '123456-789';

    my $data = {
        current => $current,
        delta => $delta,
        sku => $sku,
        channel => $channel,
    };

    if (!$topic) {
        note "Testing that no message is sent for channel ".$channel->web_name;

        $amq->clear_destination;

        lives_ok {
            $factory->transform_and_send(
                $msg_type,
                $data,
            )
        }
            "Sending to wrong channel does not die";

        $amq->assert_messages({
            assert_count => 0,
        },'No message sent');

        next CHANNEL;
    }

    note "Testing AMQ message type: $msg_type into topic: $topic";

    $amq->clear_destination($topic);

    lives_ok {
        $factory->transform_and_send(
            $msg_type,
            $data,
        )
    }
    "Can send valid message";

    $amq->assert_messages({
        destination => $topic,
        assert_header => superhashof({
            type => 'StockLevelChange',
        }),
        assert_body => superhashof({
            current  => $current,
            sku      => $sku,
            delta    => $delta,
        }),
    }, 'Message contains the correct stock level change data' );
}

done_testing;

