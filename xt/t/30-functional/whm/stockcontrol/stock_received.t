#!/usr/bin/env perl

=head1 NAME

stock_received.t - Test the stock_received message

=head1 DESCRIPTION

Create a purchase order with a delivery containing a I<Main> PGID with a status
of I<Bagged and Tagged>.

Send a I<stock_received> message and verify our quantity has increased by the
correct amount and was logged.

Create a new purchase order ready to putaway (as above). Send a
I<stock_received> message with a different storage type. Verify that the
quantity and storage type were updated and that a new row was inserted into the
log_stock table with correct data.

NOTE: This test requires AMQ to be running.
See L<Test::XTracker::RequiresAMQ> for more info.

#TAGS toobig duplication goodsin putaway iws inventory needsrefactor activemq

=cut

use NAP::policy "tt", 'test';

use Test::XT::Data;
use Test::XT::Flow;

use Test::XTracker::RunCondition iws_phase => 'iws';
use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::XTracker::Artifacts::RAVNI;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw/
:flow_status
:stock_process_status
:stock_process_type
:stock_action
:storage_type
/;

# This has to be loaded after runcondition or we get a 'bad plan' failure
use Test::XTracker::RequiresAMQ;

# General setup
my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema' );

my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app();
isa_ok( $amq, 'Test::XTracker::MessageQueue' );

my $receipt_directory = Test::XTracker::Artifacts::RAVNI->new('wms_to_xt');
isa_ok( $receipt_directory, 'Test::XTracker::Artifacts::RAVNI' );

my $framework   = Test::XT::Data->new_with_traits(
    traits => [
        'Test::XT::Data::Location',
    ]
);
isa_ok($framework, 'Test::XT::Data');

my $invar_location = $framework->data__location__get_invar_location;
isa_ok( $invar_location, 'XTracker::Schema::Result::Public::Location');


# Setup some purchase orders that we'll be putting away
my $channel = Test::XTracker::Data->channel_for_business(name=>'nap');

subtest 'send a message, wait for receipt, check stock & logs' => sub {

    my $pids = Test::XTracker::Data->find_or_create_products({
        how_many => 1,
        channel_id => $channel->id,
        force_create => 1, # true
    });
    my $pid = $pids->[0]{pid};
    my $po = Test::XTracker::Data->setup_purchase_order($pid);
    my @deliveries = Test::XTracker::Data->create_delivery_for_po( $po->id, 'putaway' );
    Test::XTracker::Data->create_stock_process_for_delivery( $_, {
        status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
        type_id   => $STOCK_PROCESS_TYPE__MAIN,
    }) for @deliveries;

    # Get the stock processes, as these will be required in our message
    my $sp_rs = $po->stock_orders
                   ->related_resultset('stock_order_items')
                   ->related_resultset('link_delivery_item__stock_order_items')
                   ->related_resultset('delivery_item')
                   ->related_resultset('stock_processes');

    # HACK HACK. some reason the stock_process_id may not be new.
    $sp_rs->search_related_rs('putaways')->delete;

    die("No stock processes found for PO:" . $po->id) unless $sp_rs->count;
    my $group_id = $sp_rs->slice(0,0)->single->group_id;


    # Take a count of the quantities in the DB pre-putaway
    my $quantities_before_msg;
    for my $sp ($sp_rs->all) {
        $quantities_before_msg->{$sp->variant->id}
            = $schema->resultset('Public::Quantity')
                     ->search({
                         variant_id => $sp->variant->id,
                         status_id  => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,})
                     ->get_column('quantity')->sum // 0;
    }

    # Send the message
    $sp_rs->reset;
    $amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::StockReceived', {sp_group_rs => $sp_rs});
    $sp_rs->reset;

    # Wait for the XTWMS receipt has appeared before going further
    note "Waiting for XTWMS receipt";
    $receipt_directory->wait_for_new_files();
    undef $receipt_directory;

    # Check the quantity has been updated
    for my $sp ($sp_rs->all) {
        my $variant_id = $sp->variant->id;
        my $new_quantity = $schema->resultset('Public::Quantity')->search({
            variant_id => $variant_id,
            status_id  => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        })->get_column('quantity')->sum;
        my $old_quantity = $quantities_before_msg->{$variant_id};
        is($new_quantity, $old_quantity + $sp->quantity, "quantity ok for variant: $variant_id");

        my $log_stock = $schema->resultset('Public::LogStock')
                               ->search(
                                   { variant_id => $variant_id },
                                   { order_by => \'date DESC' },) #'},
                               ->first;

        is( $log_stock->quantity, $sp->get_group->total_quantity, 'quantity logged correctly' );
        is( $log_stock->balance, $sp->variant->current_stock_on_channel( $channel->id ), 'balance logged correctly' );
        is( $log_stock->stock_action_id, $STOCK_ACTION__PUT_AWAY, 'stock action logged correctly' );
    }
};

subtest 'getting different quantities back from IWS, and a different storage type' => sub {
    # Create more purchase orders
    my $pids = Test::XTracker::Data->find_or_create_products({
        how_many => 1,
        channel_id => $channel->id,
        force_create => 1, # true
    });
    my $pid = $pids->[0]{pid};
    my $po = Test::XTracker::Data->setup_purchase_order($pid);
    my @deliveries = Test::XTracker::Data->create_delivery_for_po( $po->id, 'putaway' );

    Test::XTracker::Data->create_stock_process_for_delivery( $_, {
        status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
        type_id   => $STOCK_PROCESS_TYPE__MAIN,
    }) for @deliveries;
    my $sp_rs = $po->stock_orders
                   ->related_resultset('stock_order_items')
                   ->related_resultset('link_delivery_item__stock_order_items')
                   ->related_resultset('delivery_item')
                   ->related_resultset('stock_processes');
    $sp_rs->search_related_rs('putaways')->delete;

    my @sps=$sp_rs->all;
    my $payload = {
        '@type' => 'stock_received',
        items => [],
        version => '1.0',
        pgid => 'p-' . $sps[0]->group_id,
    };

    my $variant_new_storage_type;
    my $quantities_before_msg;
    for my $sp (@sps) {
        my $item = {};
        my $variant = $sp->variant;
        $item->{quantity} = $sp->quantity - 1;
        $item->{sku} = $variant->sku;

        # Set a storage type
        $variant->product->storage_type_id($PRODUCT_STORAGE_TYPE__FLAT);

        # Pick any storage type that's different to the current storage type
        my $new_storage_type = lc( $schema->resultset('Product::StorageType')
                                          ->search({
                                              id => {
                                                  '!=' => $variant->product->storage_type->id
                                              }},
                                              { rows => 1})
                                          ->first
                                          ->name
                               );
        $variant_new_storage_type->{$variant->id} = $new_storage_type;
        $item->{storage_type} = $new_storage_type;

        push @{$payload->{items}}, $item;

        $quantities_before_msg->{$sp->variant->id}
            = $schema->resultset('Public::Quantity')
                     ->search({
                         variant_id => $sp->variant->id,
                         status_id  => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,})
                     ->get_column('quantity')
                     ->sum // 0;
    }
    $sp_rs->reset;

    note p( $payload );

    my $xt_queue_name = config_var('WMS_Queues','xt_wms_inventory');
    my $res = $amq->request(
        $app,
        $xt_queue_name,
        $payload,
        { type => 'stock_received' },
    );
    ok( $res->is_success, "Result from sending to " . $xt_queue_name . " queue, 'return_request' action" );

    for my $sp (@sps) {
        my $variant = $sp->variant;
        my $variant_id = $sp->variant->id;
        my $new_quantity = $schema->resultset('Public::Quantity')
                                  ->search({
                                      variant_id => $variant_id,
                                      status_id  => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,})
                                  ->get_column('quantity')
                                  ->sum;
        my $old_quantity = $quantities_before_msg->{$variant_id};
        is($new_quantity, $old_quantity + $sp->quantity - 1, "quantity ok for variant: $variant_id");
        is(lc($variant->product->storage_type->name), $variant_new_storage_type->{$variant_id}, "Storage type update ok for variant: $variant_id" );

        my $log_stock = $schema->resultset('Public::LogStock')
                               ->search(
                                   { variant_id => $variant_id },
                                   { order_by => \'date DESC' },) #'})
                               ->first;

        is( $log_stock->quantity, $sp->get_group->total_quantity - 1,
            'quantity logged correctly ' . $log_stock->quantity . ' == ' . ($sp->get_group->total_quantity - 1));

        is( $log_stock->balance, $sp->variant->current_stock_on_channel( $channel->id ),
            'balance logged correctly ' . $log_stock->balance . ' == ' .  $sp->variant->current_stock_on_channel( $channel->id ) );

        is( $log_stock->stock_action_id, $STOCK_ACTION__PUT_AWAY, 'stock action logged correctly' );
    }
};

subtest 'have stock processes having the same variant_id, sending stock_receive message with different quantities for the same sku' => sub {
    my $pids = Test::XTracker::Data->find_or_create_products({
        how_many => 1,
        channel_id => $channel->id,
        force_create => 1, # true
    });
    my $pid = $pids->[0]{pid};
    my $product = $schema->resultset('Public::Product')->find($pid);
    my $po = Test::XTracker::Data->setup_purchase_order($pid);
    my $stock_order = $po->stock_orders->next;
    my $stock_order_item = Test::XTracker::Data->create_stock_order_item({
                                variant_id     => $stock_order->stock_order_items->next->variant_id,
                                stock_order_id => $stock_order->id,
                            });
    my @deliveries = Test::XTracker::Data->create_delivery_for_po( $po->id, 'putaway' );

    Test::XTracker::Data->create_stock_process_for_delivery( $_, {
        status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
        type_id   => $STOCK_PROCESS_TYPE__MAIN,
    }) for @deliveries;
    my $sp_rs = $po->stock_orders
                   ->related_resultset('stock_order_items')
                   ->related_resultset('link_delivery_item__stock_order_items')
                   ->related_resultset('delivery_item')
                   ->related_resultset('stock_processes');
    $sp_rs->search_related_rs('putaways')->delete;

    my @sps=$sp_rs->all;
    my $payload = {
        '@type' => 'stock_received',
        items => [],
        version => '1.0',
        pgid => 'p-' . $sps[0]->group_id,
    };

    my $delta = 10;
    my $variant_new_storage_type;
    my $quantities_before_msg;
    for my $sp (@sps) {
        my $variant = $sp->variant;
        my $item = {};
        $item->{quantity} = ++$delta;
        $item->{sku} = $variant->sku;

        # Set a storage type
        $variant->product->storage_type_id($PRODUCT_STORAGE_TYPE__FLAT);

        # Pick any storage type that's different to the current storage type
        my $new_storage_type = lc( $schema->resultset('Product::StorageType')
                                          ->search({
                                              id => {
                                                  '!=' => $variant->product->storage_type->id
                                              }},
                                              { rows => 1})
                                          ->first
                                          ->name
                               );
        $variant_new_storage_type->{$variant->id} = $new_storage_type;
        $item->{storage_type} = $new_storage_type;

        push @{$payload->{items}}, $item;

        $quantities_before_msg->{$sp->variant->id}
            = $schema->resultset('Public::Quantity')
                     ->search({
                         variant_id => $sp->variant->id,
                         status_id  => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,})
                     ->get_column('quantity')
                     ->sum // 0;
    }
    $sp_rs->reset;

    note p $payload;
    note p $quantities_before_msg;

    my $xt_queue_name = config_var('WMS_Queues','xt_wms_inventory');
    my $res = $amq->request(
        $app,
        $xt_queue_name,
        $payload,
        { type => 'stock_received' },
    );
    ok( $res->is_success, "Result from sending to " . $xt_queue_name . " queue, 'return_request' action" );
    for my $sp (@sps) {
        my $variant = $sp->variant;
        my $variant_id = $sp->variant->id;
        my $new_quantity = $schema->resultset('Public::Quantity')
                                  ->search({
                                      variant_id => $variant_id,
                                      status_id  => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,})
                                  ->get_column('quantity')
                                  ->sum;
        my $old_quantity = $quantities_before_msg->{$variant_id};
        is($new_quantity, $old_quantity + $delta*2 -1 , "quantity ok for variant: $variant_id");
        is(lc($variant->product->storage_type->name), $variant_new_storage_type->{$variant_id}, "Storage type update ok for variant: $variant_id" );
    }
    ## Check that we've added a new line to discrepancy log
    # The discrepancy will be added against the last stock process of the same variant id
    my $putaway_discrepancy_log  = $schema->resultset('Public::LogPutawayDiscrepancy')->search(
                                                            {stock_process_id  => $sps[-1]->id},
                                                            { order_by => ['recorded desc'] }
                                                        )->slice(0,0)->single;
    is ($putaway_discrepancy_log->ext_quantity , $delta + 1, "Got correct putaway discrepancy log");
    is ($putaway_discrepancy_log->channel_id , $channel->id, "Got correct channel" );
};

subtest "Ensure that a row is inserted into log_putaway_discrepancy if IWS doesn't mention a sku we were expecting at all" => sub {

    my $pids = Test::XTracker::Data->find_or_create_products({
        how_many => 2,
        channel_id => $channel->id,
        force_create => 1, # true
    });
    my $pid = $pids->[0]{pid};
    my $pid2 = $pids->[1]{pid};
    my $product = $schema->resultset('Public::Product')->find($pid2);
    $product->update({storage_type_id => 1});
    my $po = Test::XTracker::Data->setup_purchase_order($pid);
    my $stock_order_item = Test::XTracker::Data->create_stock_order_item({
                                variant_id     => $product->variants->next->id,
                                stock_order_id => $po->stock_orders->next->id,
                            });
    my @deliveries = Test::XTracker::Data->create_delivery_for_po( $po->id, 'putaway' );

    Test::XTracker::Data->create_stock_process_for_delivery( $_, {
        status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
        type_id   => $STOCK_PROCESS_TYPE__MAIN,
    }) for @deliveries;
    my $sp_rs = $po->stock_orders
                   ->related_resultset('stock_order_items')
                   ->related_resultset('link_delivery_item__stock_order_items')
                   ->related_resultset('delivery_item')
                   ->related_resultset('stock_processes');
    $sp_rs->search_related_rs('putaways')->delete;

    my @sps=$sp_rs->all;
    my $payload = {
        '@type' => 'stock_received',
        items => [],
        version => '1.0',
        pgid => 'p-' . $sps[0]->group_id,
    };
    my $quantities_before_msg;

    for my $sp (@sps) {
        my $variant = $sp->variant;
        my $item = {};
        $item->{quantity} = $sp->quantity;
        $item->{sku} = $variant->sku;


        # Set a storage type
        $variant->product->storage_type_id($PRODUCT_STORAGE_TYPE__FLAT);
        $item->{storage_type} = $variant->product->storage_type->name;

        push @{$payload->{items}}, $item;

        $quantities_before_msg->{$sp->variant->id}
            = $schema->resultset('Public::Quantity')
                     ->search({
                         variant_id => $sp->variant->id,
                         status_id  => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,})
                     ->get_column('quantity')
                     ->sum // 0;
    }
    $sp_rs->reset;

    ## delete the last item from the payload
    delete $payload->{items}[-1];
    note p $payload;

    my $xt_queue_name = config_var('WMS_Queues','xt_wms_inventory');
    my $res = $amq->request(
        $app,
        $xt_queue_name,
        $payload,
        { type => 'stock_received' },
    );
    ok( $res->is_success, "Result from sending to " . $xt_queue_name . " queue, 'return_request' action" );

    my $sp_number = 0;
    for my $sp (@sps) {
        $sp_number ++;
        my $variant = $sp->variant;
        my $variant_id = $sp->variant->id;
        my $new_quantity = $schema->resultset('Public::Quantity')
                                  ->search({
                                      variant_id => $variant_id,
                                      status_id  => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,})
                                  ->get_column('quantity')
                                  ->sum;
        my $old_quantity = $quantities_before_msg->{$variant_id};
        if ($sp_number == 1){
            is($new_quantity, ($old_quantity + $sp->quantity) || $old_quantity, "quantity ok for variant: $variant_id");
        }
        else{
            is($new_quantity, $old_quantity , "putaway quantity is zero, so quantity remais the same for variant: $variant_id");
        }
    }

    ## Check that we've added a new line to discrepancy log
    # The discrepancy will be added against the last stock process of the same variant id
    my $putaway_discrepancy_log  = $schema->resultset('Public::LogPutawayDiscrepancy')->search(
                                                            {stock_process_id  => $sps[-1]->id},
                                                            { order_by => ['recorded desc'] }
                                                        )->slice(0,0)->single;

    is ($putaway_discrepancy_log->ext_quantity , 0, "Got correct putaway discrepancy log");
    is ($putaway_discrepancy_log->channel_id , $channel->id, "Got correct channel" );

};

done_testing();
