#!/usr/bin/env perl;
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use XTracker::Config::Local 'config_var';
use Test::XTracker::MessageQueue;
use Test::XTracker::RunCondition export => qw($distribution_centre);
use XTracker::WebContent::StockManagement;
use XT::Business;
use XTracker::Constants::FromDB qw(
    :pws_action
);

my $schema      = Test::XTracker::Data->get_schema;
my $channel     = $schema->resultset('Public::Channel')->search({ name => 'JIMMYCHOO.COM' })->first;
note $channel->id;
my $amq         = Test::XTracker::MessageQueue->new;
my $queue_name  = '/queue/integration/jc/stock-update';
my $broadcast_topic_name = config_var('Producer::Stock::DetailedLevelChange','destination');

$amq->clear_destination( $queue_name );
$amq->clear_destination( $broadcast_topic_name );

my $stock_manager = XTracker::WebContent::StockManagement->new_stock_manager({
    schema     => $schema,
    channel_id => $channel->id,
});

ok( $stock_manager, 'Created a stock manager' );
isa_ok( $stock_manager, 'XTracker::WebContent::StockManagement::ThirdParty', 'Correct type' );

my ($pid) = Test::XTracker::Data->create_test_products({
    channel_id => $channel->id,
    how_many   => 1
});

my ( $chan, $pids ) = Test::XTracker::Data->grab_products({
    channel_id => $channel->id,
    how_many   => 1,
    from_products => [ $pid ],
});

my $business_logic = XT::Business->new({ });
my $plugin = $business_logic->find_plugin(
    $channel, 'Fulfilment'
);

my $variant = $schema->resultset('Public::Variant')->find($pids->[0]->{variant_id});

note $pids->[0]{variant_id};

$stock_manager->stock_update(
    quantity_change => 1,
    variant_id      => $pids->[0]->{variant_id},
    pws_action_id   => $PWS_ACTION__ORDER,
);

my $new_stock_level = $variant->product->get_saleable_item_quantity()
        ->{$channel->business->name}->{$pids->[0]->{variant_id}};

$stock_manager->commit;

$amq->assert_messages({
    destination => $queue_name,
    filter_header => superhashof({
        type => 'ThirdPartyStockUpdate',
    }),
    assert_body => superhashof({
        stock_product => superhashof({
            SKU =>  ( defined $plugin ) ? $plugin->call('get_real_sku',$variant) : $variant->sku,
            stock => superhashof({
                location => $distribution_centre,
                quantity => $new_stock_level,
                status   => 'Sellable',
            })
        })
    }),
}, 'Stock update sent via AMQ' );

$amq->assert_messages({
    destination => $broadcast_topic_name,
    filter_header => superhashof({
        type => 'DetailedStockLevelChange',
    }),
    assert_body => superhashof({
        product_id => $pids->[0]{pid},
        variants => superbagof(
            superhashof({
                variant_id => $variant->id,
                levels => superhashof({
                    saleable_quantity => $new_stock_level,
                }),
            }),
        ),
    }),
}, 'Broadcast Stock update sent via AMQ' );

done_testing();
