#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local 'config_var';

my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app;

my $broadcast_topic_name = config_var('Producer::Stock::DetailedLevelChange','destination');

my ( $channel, $pids ) = Test::XTracker::Data->grab_products({
    how_many      => 1,
    phys_vouchers => {
        how_many => 1,
    },
    virt_vouchers => {
        how_many => 1,
    },
});
my $DC = Test::XTracker::Data->whatami();

foreach my $pid ( @{$pids} ) {
    $amq->clear_destination( $broadcast_topic_name );

    my $res = $amq->request(
        $app,
        "/queue/$DC/product",
        {
            #'@type' => 'send_detailed_stock_levels',
            channel_id => $channel->id,
            product_id => $pid->{pid},
        },
        {
            type => 'send_detailed_stock_levels',
        },
    );
    ok($res->is_success,'request processed')
        or explain $res->content;

    $amq->assert_messages({
        destination => $broadcast_topic_name,
        assert_header => superhashof({
            type => 'DetailedStockLevelChange',
        }),
        assert_body => superhashof({
            product_id => $pid->{pid},
            variants => bag(
                map {
                    superhashof({ variant_id => $_->id })
                } $pid->{product}->variants
            ),
        }),
    }, 'Broadcast Stock update sent via AMQ' );
}

done_testing();
