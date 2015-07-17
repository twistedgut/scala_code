#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use Data::Dump qw/pp/;
use FindBin::libs;

use Test::Data::JSON;
use Test::XTracker::Data;

use XT::Business;
use XTracker::Constants::FromDB qw/ :currency /;

my $BASIC_BAG_MESSAGE = 'Provide basic garment bag for ';
my $LUXURY_BAG_MESSAGE = 'Provide luxury garment bag for ';

my $tests = {
    'nap' => [
        {
            input => {
                product_type => 'Random',
                price => 2000,
                currency_id => $CURRENCY__GBP,
            },
        },{
            input => {
                product_type => 'Random',
                price => 999,
                currency_id => $CURRENCY__GBP,
            },
        }
    ],
    'outnet' => [
        {
            input => {
                product_type => 'Random',
                price => 2000,
                currency_id => $CURRENCY__GBP,
            },
        },{
            input => {
                product_type => 'Random',
                price => 999,
                currency_id => $CURRENCY__GBP,
            },
        }
    ],
    'mrp' => [
        {
            input => {
                product_type => 'Random',
                price => 2000,
                currency_id => $CURRENCY__GBP,
            },
        },{
            input => {
                product_type => 'Random',
                price => 999,
                currency_id => $CURRENCY__GBP,
            },
        }
    ],
};

my $plugin_expected = {
    nap => 1,
    outnet => 1,
    mrp => 1,
};

my $schema = Test::XTracker::Data->get_schema;
#my $path = 't/data/json/content_validation';
my $daddy = XT::Business->new({ });

is(ref($daddy), 'XT::Business', 'Got the daddy instigator');

foreach my $name (keys %{$daddy->plugin_for}) {
    my $plugin =  $daddy->plugin_for->{$name};
    note "name  : $name plugin: $plugin";
}


foreach my $chan (keys %{$tests}) {

    # used to store the Order Id's created
    # to make sure they don't exist after
    # the 'rollback'
    my @order_ids;

    $schema->txn_do( sub {
        my $channel = Test::XTracker::Data->get_local_channel_or_nap($chan);
        is($channel->web_name =~ /$chan/i, 1, "Got $chan channel");
        note "===> channel: ". $channel->name;

        # create product for use
        my $po = create_product_with_product_type(undef,$channel);
        my $product = $po->stock_orders->first->public_product;

        my $plugin = $daddy->find_plugin($channel,'OrderImporter');

        next if (!$plugin_expected->{$chan});

        is(ref($plugin),
            "XT::Business::Logic::"
            .$channel->business->short_name
            ."::OrderImporter",
            'Found plugin');

        my $customer = Test::XTracker::Data->create_dbic_customer({
            channel_id => $channel->id,
        });

        note "customer_id : ". $customer->id;

        foreach my $test (@{$tests->{$chan}}) {
            my $input = $test->{input};

            # create order with one of each product
            my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
                base => {
                    currency_id => $input->{currency_id},
                    customer_id => $customer->id,
                    channel_id => $channel->id,
                },
                pids => [{
                    pid        => $product->id,
                    product    => $product,
                    variant    => $product->variants->first,
                    variant_id => $product->variants->first->id,
                    size_id    => $product->variants->first->size_id,
                    sku        => $product->variants->first->sku,
                }],
                attrs => [
                    { price => $input->{price} },
                ],
            });
            push @order_ids, $order->id;

            note "input: ". pp($input);
            note "order_id: ". $order->id;
            note "customer_id: ". $order->customer_id;
            my $customer = $order->customer;

            $order->discard_changes;
        }

        # rollback changes
        $schema->txn_rollback;
    } );

    # check no Order Id's exist after the Rollback, to make sure no
    # stray 'commits' have happened in adding the Promotion to the Order
    cmp_ok( $schema->resultset('Public::Orders')->search( { id => \@order_ids } )->count, '==', 0,
                   "Can't find Order Id's in 'orders' table after 'txn_rollback'" );
}

done_testing;


sub create_product_with_product_type {
    my($product_type_name,$channel) = @_;

    my $po = Test::XTracker::Data->create_from_hash({
        channel_id      => $channel->id,
        placed_by       => 'Bobby',
        stock_order     => [{
            product         => {
                style_number    => 'NAP IN-THE-BOX',
                variant         => [{
                    size_id         => 1,
                    stock_order_item    => {
                        quantity            => 40,
                    },
                }],
                product_channel => [{
                    channel_id      => $channel->id,
                }],
                product_attribute => {
                    description     => 'New Description',
                },
                price_purchase => {},
            },
        }],
    });
}

1;
