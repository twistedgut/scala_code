#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::MessageQueue;
use XTracker::Comms::FCP        qw( amq_update_web_stock_level );
use Test::XTracker::RunCondition dc => 'DC1';

# we don't really care what channel we get
# as long as we get one that the test can use
# eval{} a few known constants
my $channel_id;
BEGIN {
    use vars qw<$CHANNEL__NAP_INTL $CHANNEL__NAP_AM>;
    use XTracker::Constants::FromDB qw( :channel );
    eval { $channel_id ||= $CHANNEL__NAP_INTL; };
    eval { $channel_id ||= $CHANNEL__NAP_AM;   };
}

# a shared producer for the script
my $amq = Test::XTracker::MessageQueue->new();
isa_ok( $amq, 'Test::XTracker::MessageQueue' );

# old-style: dies
OLD_STYLE_THROWS_OK: {
    my ($self_dbh,$web_dbh,$exch_item_variant_id);
    throws_ok {
        amq_update_web_stock_level(
            $self_dbh, $web_dbh,
            {
                quantity_change => 1,
                variant_id => $exch_item_variant_id,
            }
        );
    }
    qr/^first argument should be something with a transform_and_send method/,
    q/correct error when passed a $dbh/;
}

my $pids = Test::XTracker::Data->find_or_create_products({hom_many=>1});
my $variant_id = $pids->[0]->{variant_id};
my $sku = $pids->[0]->{sku};

my $dest='/queue/nap-intl-stock.update';

# new-style: lives
NEW_STYLE_LIVES_OK: {
    $amq->clear_destination($dest);

    # positive
    lives_ok {
        amq_update_web_stock_level(
            $amq->producer,
            { quantity_change => '17', variant_id => $variant_id, channel_id => $channel_id }
        );
    } q/amq_update_web_stock_level() lives with correct arguments/;

    $amq->assert_messages({
        destination => $dest,
        assert_header => superhashof({
            type => 'StockUpdate',
        }),
        assert_body => superhashof({
            quantity_change => 17,
        }),
    }, 'message has correct quantity_change');

    $amq->clear_destination($dest);

    # negative quantity
    lives_ok {
        amq_update_web_stock_level(
            $amq->producer,
            { quantity_change => '-23', variant_id => $variant_id, channel_id => $channel_id }
        );
    } q/amq_update_web_stock_level() lives with correct arguments/;

    $amq->assert_messages({
        destination => $dest,
        assert_header => superhashof({
            type => 'StockUpdate',
        }),
        assert_body => superhashof({
            quantity_change => -23,
            sku => $sku,
        }),
    }, 'message has correct quantity_change and a SKU');
}

DEATH_WITH_NO_CHANNEL: {
    throws_ok {
        amq_update_web_stock_level(
            $amq->producer,
            { quantity_change => '-23', variant_id => $variant_id}
        );
    } qr/cannot find channel/,
    q/amq_update_web_stock_level() dies without a channel_id/;
}

done_testing;
