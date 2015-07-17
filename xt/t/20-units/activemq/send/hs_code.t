#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::MessageQueue;
use Test::Exception;
use XTracker::Config::Local qw/config_var/;

=head2 Test summary

- Create a new hs_code
- Create an AMQ message
- Validate that it's sane

=cut

my $amq = Test::XTracker::MessageQueue->new;
my $schema = Test::XTracker::Data->get_schema;
my $factory = $amq->producer;

isa_ok( $amq, 'Test::XTracker::MessageQueue' );
isa_ok( $schema, 'XTracker::Schema' );
isa_ok( $factory, 'Net::Stomp::Producer' );

my $msg_type = 'XT::DC::Messaging::Producer::Sync::HSCode';
my $queue = config_var('Producer::Sync::HSCode', 'destination');

note "testing AMQ message type: $msg_type into queue: $queue";

my $hscode_rs = $schema->resultset('Public::HSCode')
                    ->search(
                        {
                            hs_code => {'~', '^[0-9]+$'},
                        },
                        { order_by => 'RANDOM()', rows => 1 }
                    )->single();

my $hs_code = $hscode_rs->hs_code;

note "hs_code = $hs_code";

my $data = { hs_code => $hs_code };

$amq->clear_destination($queue);

lives_ok {
    $factory->transform_and_send(
        $msg_type,
        $data,
    )
}
"Can send valid message";

$amq->assert_messages({
    destination => $queue,
    assert_header => superhashof({
        type => 'hs_create',
    }),
    assert_body => superhashof({
        'hs_code' => $hs_code
    }),
}, 'Message contains the correct HSCode data and is going in the correct queue'
);

done_testing;
