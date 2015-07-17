#!/usr/bin/env perl

=head1 NAME

putaway.t - Test the Putaway process

=head1 DESCRIPTION

Test the Putaway process

#TAGS goodsin putaway iws prl loops http voucher log pws activemq whm

=cut

use NAP::policy "tt", 'test';

use XTracker::Constants::FromDB qw(
    :authorisation_level
    :delivery_action
    :delivery_item_status
    :delivery_status
    :pws_action
    :stock_action
    :stock_process_status
    :stock_process_type
    :flow_status
    :putaway_type
);
use Test::XTracker::Data;
use Test::XTracker::LocationMigration;
use Test::XTracker::Mechanize::GoodsIn;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local         qw( config_var );
use XTracker::Database::Stock       qw( get_total_pws_stock );
use Test::XTracker::RunCondition
    export => [qw( $iws_rollout_phase $prl_rollout_phase )];

my $is_dc2 = config_var('DistributionCentre', 'name') eq 'DC2';

use Test::XT::Flow;
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::WMS',
        'Test::XT::Data::Location',
    ],
);

unless ( XTracker::Config::Local::config_var(qw/IWS rollout_phase/) ) {
    $framework->data__location__initialise_non_iws_test_locations;
}

# set for global use
my $nap_channel_id  = Test::XTracker::Data->get_local_channel()->id;

# Set this as a global for the subs in this test to use. This is the username
# of the logged in user.
my $operator_name = 'it.god';

my ($channel,$pids) = Test::XTracker::Data->grab_products( { how_many => 1, channel => 'nap' } );
my $TEST_PRODUCT_ID = $pids->[0]{pid};

note "Testing product $TEST_PRODUCT_ID";
run_tests( $TEST_PRODUCT_ID );

# Voucher tests
for (
    # SP Type name, live, SP Type ID,                    Voucher update args
    [ 'Main',       0,    $STOCK_PROCESS_TYPE__MAIN,    { upload_date => undef } ],
    [ 'Main',       1,    $STOCK_PROCESS_TYPE__MAIN,    { upload_date => DateTime->now( time_zone => 'local' ) } ],
    [ 'Surplus',    1,    $STOCK_PROCESS_TYPE__SURPLUS, { upload_date => DateTime->now( time_zone => 'local' ) } ],
) {
    my ( $sp_type_name, $live_flag, $sp_type_id, $voucher_args ) = @$_;

    my $voucher = Test::XTracker::Data->create_voucher();
    $voucher->update( $voucher_args );

    note "Testing $sp_type_name with " . ( $live_flag ? 'LIVE' : 'NON-LIVE' ) .
        ' voucher ' . $voucher->id;
    run_tests( $voucher->id, $sp_type_id, $live_flag );

}

done_testing;

sub run_tests {
    my ( $id, $type_id, $live ) = @_;
    # Test product

    # decide if pid is voucher or not as we can't test
    # AMQ stuff for normal products at the moment
    my $is_voucher  = 0;
    my $schema = Test::XTracker::Data->get_schema;
    if ( defined $schema->resultset('Voucher::Product')->find( $id ) ) {
        $is_voucher = 1;
    }

    # set-up ActiveMQ ready for the tests
    my $mq  = setup_amq( $nap_channel_id );

    $live   = 1     if ( !defined $live );       # default to product/voucher being live

    $type_id ||= $STOCK_PROCESS_TYPE__MAIN;
    my $po = prepare_putaway( $id, {
        status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
        type_id   => $type_id,
    });

    my $sp_rs = $po->stock_orders
                   ->related_resultset('stock_order_items')
                   ->related_resultset('link_delivery_item__stock_order_items')
                   ->related_resultset('delivery_item')
                   ->related_resultset('stock_processes');
    die("No stock processes found for PO $id") unless $sp_rs->count;
    # put some definite order on the qry
    $sp_rs  = $sp_rs->search( {}, { order_by => 'id' } );

    my $group_id = $sp_rs->slice(0,0)->single->group_id;

    Test::XTracker::Data->grant_permissions( 'it.god', 'Goods In', 'Putaway',
        $AUTHORISATION_LEVEL__MANAGER );
    my $mech = Test::XTracker::Mechanize::GoodsIn->new();
    $mech->login_as_department( 'Stock Control' );

    if ( $iws_rollout_phase == 0 && $prl_rollout_phase == 0 ) {
        # Use HandHeld until this page stops taking forever
        $mech->get_ok('/GoodsIn/Putaway?view=HandHeld');
        $mech->submit_form_ok({
            form_name => "Process Group",
            with_fields => { process_group_id => $group_id, },
            button      => 'submit',
        }, "begin putaway for group $group_id");
        $mech->no_feedback_error_ok;
    }

    my $is_faulty_voucher
        = ($sp_rs->get_voucher and $type_id == $STOCK_PROCESS_TYPE__FAULTY)
        ? 1
        : 0;

    my @location_migration_tests;

    # The form reloads for every variant in the stock process group
    foreach my $sp ( $sp_rs->all ) {
        # Get a location for shelving the products
        # If stock_process_type is faulty and we have a voucher we want to
        # shelve it in dead stock
        my $location = $is_faulty_voucher
                     ? get_location(
                        { status_id=>$FLOW_STATUS__DEAD_STOCK__STOCK_STATUS, is_dc2 => $is_dc2 })
                     : location_for_stock_process( $sp ) || get_location({ is_dc2 => $is_dc2 });

        isa_ok( $location, 'XTracker::Schema::Result::Public::Location' );
        note "Put away at location_id " . $location->id;

        # Ensure all quantities for that location are 0
        # This severely reduces how useful this test is.
        $location->quantities->update({quantity=>0});

        # Having zero'd it, let's start the variant_id test process
        my $variant_id = $sp->variant->id;
        my $quantity   = $sp->quantity;

        my $location_test = Test::XTracker::LocationMigration->new(
            variant_id => $variant_id
        );
        $location_test->snapshot('Pre-putaway for variant ' . $variant_id);
        push(@location_migration_tests,
            [ $location_test, $variant_id, $quantity ] );

        if ( $iws_rollout_phase == 0 && $prl_rollout_phase == 0 ) {
            # Putaway
            $mech->putaway_stock_process_ok( $sp, $location, $nap_channel_id );
            putaway_quantity_ok( $sp );
        }

        is( $sp->discard_changes->type_id, $STOCK_PROCESS_TYPE__DEAD,
          'faulty voucher stock process type set to dead' )
            if $is_faulty_voucher;
    }

    if ( $iws_rollout_phase > 0 ) {

        $framework->flow_wms__send_stock_received(
            sp_group_rs => $sp_rs,
            operator    => $mech->logged_in_as_object,
        );

    } elsif ( $prl_rollout_phase > 0 ) {

        # We don't go any further if we're using PRLs, because with them we have
        # to do putaway prep, and there are lots of other more complicated
        # tests dealing with putaway prep, advice and advice_response messages.
        return;

    } else {

        # Complete the putaway process
        $mech->submit_form_ok({
            form_name => "putawayForm",
            with_fields => {
                active_channel_id   => $nap_channel_id,
                channel_config      => 'NAP',
                delivery_channel_id => $nap_channel_id,
                process_group_id    => $group_id,
                putaway_type        => $PUTAWAY_TYPE__GOODS_IN,
                source              => 'desktop',
                complete            => 1,
             },
            button => 'submit',
        }, "complete putaway for group_id $group_id");
        $mech->no_feedback_error_ok;

    }

    # Test stock moved around reliably
    for ( @location_migration_tests ) {
        my ( $location_test, $variant_id, $quantity ) = @$_;
        $location_test->snapshot('Post-putaway for variant ' . $variant_id );
        $location_test->test_delta(
            from => 'Pre-putaway for variant ' . $variant_id,
            to   => 'Post-putaway for variant ' . $variant_id,
            stock_status => { 'Main Stock' => 0+$quantity }
        );
    }

    check_num_web_updates_ok( $sp_rs, $mq, $live )      if ( $is_voucher );
    for ( $sp_rs->all ) {
        location_quantity_ok( $_ );
        stock_log_ok( $_, $is_faulty_voucher );
        update_web_ok( $_, $mq )            if ( $live && $is_voucher );
        pws_stock_log_ok( $_, $live );
    }
    delivery_log_ok( $group_id, $type_id ) unless $is_faulty_voucher;
        statuses_ok( $group_id );
}

=head2 delivery_log_ok

Check the log_delivery table is updated correctly

=cut

sub delivery_log_ok {
    my ( $group_id, $type_id ) = @_;

    my $schema = Test::XTracker::Data->get_schema;
    my $sp_rs = $schema->resultset('Public::StockProcess');
    my $sp_group_rs = $sp_rs->get_group( $group_id );

    # As we deleted all it.god, this should return one row and thus no
    # warnings when calling ->single
    my $log_delivery = $schema->resultset('Public::LogDelivery')->search({
        operator_id => get_operator_by_username($operator_name)->id,
    })->single;
    is( $log_delivery->type_id, $type_id,
        'type is main' );
    is( $log_delivery->quantity, $sp_group_rs->total_quantity,
        'group quantity matches' );
    is( $log_delivery->delivery_action_id, $DELIVERY_ACTION__PUTAWAY,
        'action is putaway' );
    is( $log_delivery->delivery_id, $sp_group_rs->first->delivery_item->delivery_id,
        'delivery id is correct' );
}

=head2 stock_log_ok

Check the log_stock table is updated correctly

=cut

sub stock_log_ok {
    my ( $stock_process, $is_faulty_voucher ) = @_;

    # The consumer for stock_received only knows how to deal with usernames
    # defaulting to $APPLICATION_OPERATOR_ID if none has been defined
    my $operator = get_operator_by_username($operator_name);
    my $soi = $stock_process->delivery_item->stock_order_item;
    my $variant = $soi->variant;

    my $schema = $stock_process->result_source->schema;
    my $log_stock = $schema->resultset('Public::LogStock')->search(
        { variant_id => $variant->id,
          channel_id => $soi->stock_order->purchase_order->channel_id,
          operator_id => $operator->id, },
        { order_by => \'date DESC' },
    )->first;

    my $stock_action_id = $is_faulty_voucher
                        ? $STOCK_ACTION__DEAD__DASH__NO_RTV
                        : $STOCK_ACTION__PUT_AWAY;
    is( $log_stock->quantity, $stock_process->get_group->total_quantity,
        'quantity logged correctly' );
    is( $log_stock->balance, $variant->current_stock_on_channel( $nap_channel_id ),
        'balance logged correctly' );
    is( $log_stock->stock_action_id, $stock_action_id,
        'stock action logged correctly' );
}

=head2 check_statuses_ok

Check the correct updates were made to the database. Currently this only works
for completed items.

=cut

sub statuses_ok {
    my ( $group_id ) = @_;
    my $schema = Test::XTracker::Data->get_schema;
    my $sp_rs = $schema->resultset('Public::StockProcess')
                       ->search({group_id=>$group_id});

    my $delivery_item;
    # Check stock process rows
    foreach my $stock_process ( $sp_rs->all ) {
        my $location = location_for_stock_process( $stock_process );
        my $putaway = $stock_process->search_related( 'putaways',
                                        { location_id => $location->id } )
                                    ->slice(0,0)
                                    ->single;
        ok($putaway->complete, "putaway for @{[$stock_process->id]} is complete");
        ok($stock_process->complete, 'stock process is complete');
        is($stock_process->status_id, $STOCK_PROCESS_STATUS__PUTAWAY,
            'stock process status is putaway' );
        $delivery_item = $stock_process->delivery_item;
    }
    is($delivery_item->status_id, $DELIVERY_ITEM_STATUS__COMPLETE,
        "delivery item @{[$delivery_item->id]} is complete");
    my $delivery = $delivery_item->delivery;
    is($delivery->status_id, $DELIVERY_STATUS__COMPLETE,
        "delivery @{[$delivery->id]} is complete");
}

=head2 check_putaway_quantity_ok

Checks the putaway quantity is correct

=cut

sub putaway_quantity_ok {
    my ( $stock_process ) = @_;
    my $location = location_for_stock_process( $stock_process );
    my $putaway = $stock_process->search_related('putaways',
                                    {location_id => $location->id})
                                ->slice(0,0)
                                ->single;
    isa_ok( $putaway, 'XTracker::Schema::Result::Public::Putaway');
    is( $putaway->quantity, $stock_process->quantity,
        'putaway quantity correct' );
}

=head2 check_location_quantity_ok

Checks the quantity at the location is correct

=cut

sub location_quantity_ok {
    my ( $stock_process ) = @_;
    my $location = location_for_stock_process( $stock_process );
    my $quantity_rs = $location->quantities
                               ->search({
                                    variant_id=>$stock_process->variant->id,
                                    channel_id=>$stock_process->channel->id,
                                    status_id =>$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                               });
    my $quantity = $quantity_rs->next;
    isa_ok( $quantity, 'XTracker::Schema::Result::Public::Quantity' );
    is( $quantity_rs->next, undef, 'Only one quantity found' );
    is( $quantity->quantity, $stock_process->quantity,
        'quantity in inventory correct' );
}

=head2 check_num_web_updates_ok

Checks the number of process connected to the web-site have happened
depending on whether the product/voucher was live.

=cut

sub check_num_web_updates_ok {
    my ( $sp_rs, $mq, $live )   = @_;

    my $amq_messages = ( $live ? $sp_rs->count() : 0 );
    # get number of messages returned
    $mq->{amq}->assert_messages({
        destination => $mq->{queue},
        assert_count => $amq_messages,
    }, "Number of Stock Update messages sent as expected ($amq_messages)" );
}

=head2 update_web_ok

Checks the Stock Update message for the web-site got created ok.

=cut

sub update_web_ok {
    my ( $stock_process, $mq )      = @_;

    my $soi = $stock_process->delivery_item->stock_order_item;
    my $variant = $soi->variant;

    $mq->{amq}->assert_messages( {
        destination => $mq->{queue},
        filter_header => superhashof({
            type => 'StockUpdate',
        }),
        filter_body => superhashof({
            sku => $variant->sku,
        }),
        assert_body => superhashof({
            quantity_change => $stock_process->quantity,
        }),
    }, "Stock Update AMQ message sent as expected" );
}

=head2 pws_stock_log_ok

Check the log_pws_stock table is updated correctly

=cut

sub pws_stock_log_ok {
    my ( $stock_process, $live )    = @_;

    my $operator = get_operator_by_username($operator_name);
    my $soi = $stock_process->delivery_item->stock_order_item;
    my $variant = $soi->variant;

    my $schema = $stock_process->result_source->schema;
    my $log_stock = $schema->resultset('Public::LogPwsStock')->search(
        { variant_id => $variant->id,
          channel_id => $soi->stock_order->purchase_order->channel_id,
          operator_id => $operator->id, },
        { order_by => \'date DESC' },
    );

    # should have log if live else not
    if ( $live ) {
        my $free_stock  = get_total_pws_stock( $schema->storage->dbh, {
                                            type => 'variant_id',
                                            id => $variant->id,
                                            channel_id => $soi->stock_order->purchase_order->channel_id
                                    } );

        is( $log_stock->first->quantity, $stock_process->get_group->total_quantity,
            'log_pws_stock quantity logged correctly' );
        is( $log_stock->first->balance, $free_stock->{ $variant->id }{quantity},
            'log_pws_stock balance logged correctly' );
        is( $log_stock->first->pws_action_id, $PWS_ACTION__PUTAWAY,
            'log_pws_stock pws action logged correctly' );
    }
    else {
        ok( !defined $log_stock->first, 'No log_pws_stock record created' );
    }
}

=head2 prepare_putaway

Create a purchase order and place all related db rows into an appropriate
testing state.

=cut

sub prepare_putaway {
    my ( $ids, $sp_args ) = @_;

    my $po = Test::XTracker::Data->setup_purchase_order( $ids );
    my @deliveries
        = Test::XTracker::Data->create_delivery_for_po( $po->id, 'putaway' );

    Test::XTracker::Data->create_stock_process_for_delivery( $_, $sp_args )
        for @deliveries;

    # Clear log for testing log entry created correctly
    my $operator = get_operator_by_username($operator_name);
    my $schema = Test::XTracker::Data->get_schema;
    $schema->resultset("Public::Log$_")->search({operator_id=>$operator->id})->delete
        for qw{Delivery Stock};
    return $po;
}

=head2 location_for_stock_process

Get the location the stock process is currently in.

=cut

sub location_for_stock_process {
    my ( $stock_process ) = @_;

    if ( $iws_rollout_phase > 0 ) {

        my $schema = $stock_process->result_source->schema;
        return $schema->resultset('Public::Location')->get_iws_location;

    } else {

        my $sp_location_rs = $stock_process->locations;
        my $sp_location_count = $sp_location_rs->count;

        die "More than one location found for ".$stock_process->id
            if $sp_location_count > 1;

        return $sp_location_rs->slice(0,0)->single;

    }
}

=head2 get_location

Gets a location - you can pass it a hashref and specify a type_id

=cut

sub get_location {
    my ( $args ) = @_;
    my $schema = Test::XTracker::Data->get_schema;
    my $status_id = $args->{status_id} || $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;
    my $loc_rs = $schema->resultset('Public::Location')->search({
        'location_allowed_statuses.status_id' => $status_id,
    }, {
        join => 'location_allowed_statuses',
    });
    if ($args->{is_dc2}) {
        # floor depends on stock status
        my $floor;
        if ( $status_id == $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS ) {
            # main stock is no longer channelised
            $floor = 1;
        } else {
            # other stock is on 024
            $floor = 4;
        }
        $loc_rs = $loc_rs->get_locations({ floor => $floor });
    }
    return $loc_rs->slice(0,0)->single;
}

=head2 get_operator_by_username

Gets the operator object by username

=cut

sub get_operator_by_username {
    my ( $username ) = @_;
    return Test::XTracker::Data->get_schema
                               ->resultset('Public::Operator')
                               ->get_operator_by_username($username);
}

=head2 setup_amq

Gets a Test AMQ instance and clears the stock update queue.

=cut

sub setup_amq {
    my $channel_id  = shift;

    my $amq = Test::XTracker::MessageQueue->new;
    my $queue_name;

    # get the queue name for the Stock Update queue based on the channel
    $queue_name = $amq->make_queue_name( $channel_id, 'stock.update' );
    note "Using AMQ: ".$queue_name;
    $amq->clear_destination( $queue_name );

    return {
            amq => $amq,
            queue => $queue_name
        };
}
