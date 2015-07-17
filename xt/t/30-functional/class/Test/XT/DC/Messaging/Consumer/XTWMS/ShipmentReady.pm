package Test::XT::DC::Messaging::Consumer::XTWMS::ShipmentReady;

use NAP::policy "tt", 'test';

use parent 'NAP::Test::Class';

use Test::XTracker::RunCondition iws_phase => 'iws';
use Test::XTracker::Data;
use Test::XT::Flow;
use Test::XT::Data::Location;
use Test::XT::Data::Container;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw(
    :flow_status
    :shipment_item_status
    :packing_exception_action
);
use Data::Dump  qw( pp );
use Test::XTracker::Artifacts::RAVNI;

=head1 NAME

Test::XT::DC::Messaging::Consumer::XTWMS::ShipmentReady

=cut

sub startup : Test(startup) {
    my $self = shift;

    $self->SUPER::startup;

    $self->{framework} = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Location',
            'Test::XT::Data::Order',
            'Test::XT::Flow::WMS',
        ],
    );

    # create an Invar location
    $self->{invar_loc} = $self->{framework}->data__location__get_invar_location;
    $self->{schema} = Test::XTracker::Data->get_schema;

    @{$self}{qw/amq app/} = Test::XTracker::MessageQueue->new_with_app;
}

sub wms_to_xt { Test::XTracker::Artifacts::RAVNI->new('wms_to_xt'); }

sub prepare_order {
    my ($self, $channel,$products,$quantities)=@_;

    if (!defined $quantities) {
        $quantities = 5;
    }
    if (!ref($quantities)) {
        $quantities = {
            map {; $_->{variant_id}, $quantities } @$products
        };
    }

    # Create an order in the 'selected' state

    my $order_data = $self->{framework}->selected_order(
        channel => $channel,
        products => $products,
    );

    my $shipment_id  = $order_data->{'shipment_id'};
    note "Shipment id $shipment_id created";

    # make sure the products have some stock in new Invar location
    foreach my $prod_ob (@{$order_data->{'product_objects'}}){
        note "creating quantity row for ". $prod_ob->{variant_id} . " in Invar location";
        $self->{schema}->resultset('Public::Quantity')->update_or_create({
            variant_id  => $prod_ob->{variant_id},
            location_id => $self->{invar_loc}->id,
            channel_id  => $order_data->{channel_object}->id,
            status_id   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            quantity    => $quantities->{$prod_ob->{variant_id}},
        });
    }

    return $order_data;
}

sub prepare_empty_message {
    my ($self, $order_data)=@_;

    my $shipment_id=$order_data->{shipment_id};

    # Generate a payload and send a shipment_ready message
    my $payload = {
        '@type'     => 'shipment_ready',
        'shipment_id' => 's-' . $shipment_id,
        'containers' => [],
        'version' => '1.0',
    };

    return ($payload,{type => 'shipment_ready'});
}

sub prepare_message {
    my ($self, $shipment, $containers,$merge)=@_;

    my $shipment_id=$shipment->id;

    # Generate a payload and send a shipment_ready message
    my $payload = {
        '@type'     => 'shipment_ready',
        'shipment_id' => 's-' . $shipment_id,
        'containers' => [],
        'version' => '1.0',
    };
    foreach my $container (@$containers){
        push @{ $payload->{containers} },
            {
                container_id => $container,
                items => [],
            }
        }

    my $shipment_items = $shipment->shipment_items;
    my $item_container_map = {};my %sku_q_map;my %sku_c_map;
    while (my $item = $shipment_items->next) {
        my $sku = $item->get_true_variant->sku;
        if ($merge && $sku_q_map{$sku}) {
            $sku_q_map{$sku}->{quantity}++;
            $item_container_map->{$item->id} = $sku_c_map{$sku};
            next;
        }

        # alternate which of the containers to put the item in
        my $container_hash = $payload->{containers}->[ (scalar keys %$item_container_map) % (scalar @$containers) ];
        # store where we put it for testing later
        $item_container_map->{$item->id} = $container_hash->{container_id};
        # and put it in there
        push @{ $container_hash->{items} },
            {
                'sku' => $sku,
                'quantity' => 1,
                'pgid' => 'foo-0',
            };
        $sku_q_map{$sku}=$container_hash->{items}[-1];
        $sku_c_map{$sku}=$container_hash->{container_id};
    }

    return ($payload,{ type => 'shipment_ready' },$item_container_map);
}

sub quantity_for {
    my ($self, $variant_id,$channel_id) = @_;

    $self->{schema}->resultset('Public::Quantity')->find({
        variant_id  => $variant_id,
        location_id => $self->{invar_loc}->id,
        channel_id  => $channel_id,
        status_id   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    })->quantity;
}

sub check_message_effects {
    my ($self, $res,$order_data,$item_container_map,$quantities) = @_;

    my @shipment_items = $order_data->{shipment_object}->shipment_items->all;

    if (!defined $quantities) {
        # default: same default as prepare_order, minus one per ordered product
        $quantities = {
            map {; $_->variant_id, 5 } @shipment_items
        };
        for (@shipment_items) {
            $quantities->{ $_->variant_id() }--;
        }
    }
    if (!ref($quantities)) {
        $quantities = {
            map {; $_->variant_id, $quantities } @shipment_items
        };
    }

    # check it gets consumed
    ok( $res->is_success, 'shipment_ready message processed ok' );

    # check that the shipment_items are correctly updated
    for my $item (@shipment_items){
        #  * shipment items should be 'picked'
        is($item->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__PICKED, 'Shipment item '. $item->id .' ('.$item->get_sku.') in "picked" status');
        #  * shipment items should all have correct container values
        is($item->container_id, $item_container_map->{$item->id}, "Stored container id is '$item_container_map->{$item->id}' as we expect");
        #  * quantities should have been decremented in quantity table
        my $quantity = $self->quantity_for($item->variant_id,$order_data->{channel_object}->id);
        is($quantity, $quantities->{ $item->variant_id }, "quantity is now ".$quantities->{ $item->variant_id });
    }
}

=head1 TESTS

=head2 test_simple_order_processing

=cut

sub test_simple_order_processing : Tests {
    my $self = shift;

    my @container_ids = Test::XT::Data::Container->get_unique_ids( { how_many => 2 });
    my ($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 5,
        force_create => 1,
    });

    my $order_data = $self->prepare_order( $channel, [ @$pids[0..4] ] );
    my ($payload,$header,$item_container_map) = $self->prepare_message(
        $order_data->{shipment_object}, [ @container_ids[0..1] ]
    );
    my $wms_to_xt = $self->wms_to_xt;
    my $res = $self->{amq}->request(
        $self->{app},
        config_var('WMS_Queues','xt_wms_fulfilment'),
        $payload,
        $header,
    );
    $wms_to_xt->expect_messages({  messages => [ { type => 'shipment_ready' } ] });

    $self->check_message_effects($res,$order_data,$item_container_map);
}

=head2 test_shipment_ready_with_no_containers_and_some_selected_items

=cut

sub test_shipment_ready_with_no_containers_and_some_selected_items : Tests {
    my $self = shift;

    my ($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 5,
        force_create => 1,
    });

    my $order_data = $self->prepare_order( $channel, [ @$pids[0..4] ] );

    # make one item cancel_pending
    my $shipment_items = $order_data->{shipment_object}->shipment_items;
    $shipment_items->first->update({shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING});

    my $item_status_hash;
    $shipment_items->reset;
    while (my $si = $shipment_items->next){
        $item_status_hash->{$si->id} = $si->shipment_item_status_id;
    }
    my ($payload,$header) = $self->prepare_empty_message( $order_data );

    my $res = $self->{amq}->request(
        $self->{app},
        config_var('WMS_Queues','xt_wms_fulfilment'),
        $payload,
        $header,
    );
    ok( $res->is_error, 'shipment_ready message could not be processed' );

    $shipment_items->reset;
    while (my $si = $shipment_items->next){
        is ($si->shipment_item_status_id , $item_status_hash->{$si->id}, 'All statuses( in this case: '. $si->shipment_item_status->status .')should remain the same');
    }
}

=head2 test_shipment_ready_with_no_containers_and_with_cancelled_or_CP_items_only

=cut

sub test_shipment_ready_with_no_containers_and_with_cancelled_or_CP_items_only : Tests {
    my $self = shift;

    my ($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 2,
        force_create => 1,
    });

    my $order_data = $self->prepare_order( $channel, [ @$pids[0..1] ] );

    # make one item cancel_pending
    my $shipment_items = $order_data->{shipment_object}->shipment_items;
    $shipment_items->next->update({shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING});
    $shipment_items->next->update({shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED});

    my $item_status_hash = {map {
        $_->id => $_->shipment_item_status_id
    } $shipment_items->all};

    $self->{framework}->flow_wms__send_shipment_ready(
        shipment_id => $order_data->{shipment_object}->id
    );

    for my $si ($shipment_items->all){
        if ($item_status_hash->{$si->id} == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING){
            is ($si->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__CANCELLED, 'Cancel Pending items not mentioned in the message should become Cancelled');
        }
        else{
            is ($si->shipment_item_status_id , $item_status_hash->{$si->id}, 'Other statuses( in this case: '. $si->shipment_item_status->status .')should remain the same');
        }
    }
}

=head2 test_shipment_with_two_identical_items_not_merged_in_message

=cut

sub test_shipment_with_two_identical_items_not_merged_in_message : Tests {
    shift->_shipment_with_two_identical_items_merged_in_message;
}

=head2 test_shipment_with_two_identical_items_merged_in_message

=cut

sub test_shipment_with_two_identical_items_merged_in_message : Tests {
    shift->_shipment_with_two_identical_items_merged_in_message(1);
}

sub _shipment_with_two_identical_items_merged_in_message {
    my ( $self, $merge ) = @_;

    my @container_ids = Test::XT::Data::Container->get_unique_ids( { how_many => 1 });
    my ($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 1,
        force_create => 1,
    });

    my $order_data = $self->prepare_order( $channel, [ @$pids[0,0] ] );
    my ($payload,$header,$item_container_map) = $self->prepare_message(
        $order_data->{shipment_object}, [ $container_ids[0] ], $merge
    );
    my $wms_to_xt = $self->wms_to_xt;
    my $res = $self->{amq}->request(
        $self->{app},
        config_var('WMS_Queues','xt_wms_fulfilment'),
        $payload,
        $header,
    );
    $wms_to_xt->expect_messages({  messages => [ { type => 'shipment_ready' } ] });

    $self->check_message_effects($res,$order_data,$item_container_map);
}

=head2 test_order_with_size_change

=cut

sub test_order_with_size_change : Tests {
    my $self = shift;

    my @container_ids = Test::XT::Data::Container->get_unique_ids( { how_many => 2 });
    my ($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 2, # we only use one, but need the other to make grab_multi_variant_product() work
        force_create => 1,
    });

    my (undef,$multi_variant) = Test::XTracker::Data->grab_multi_variant_product({
        channel => $channel,
        not => [ $pids->[0]->{variant_id} ], # don't want to use the same variant twice!
    });

    my $stock_quantity = {
        $pids->[0]->{variant_id} => 5,
        $multi_variant->[0]->{variant_id} => 5,
    };

    my $order_data = $self->prepare_order( $channel, [ $pids->[0], $multi_variant->[0] ], $stock_quantity );
    my ($payload,$header,$item_container_map) = $self->prepare_message(
        $order_data->{shipment_object}, [ $container_ids[0] ]
    );
    my $wms_to_xt = $self->wms_to_xt;
    my $res = $self->{amq}->request(
        $self->{app},
        config_var('WMS_Queues','xt_wms_fulfilment'),
        $payload,
        $header,
    );
    $wms_to_xt->expect_messages({  messages => [ { type => 'shipment_ready' } ] });

    for (values %$stock_quantity) { --$_ };

    $self->check_message_effects($res,$order_data,$item_container_map, $stock_quantity );

    # let's simulate a size change
    my $shipment = $order_data->{shipment_object};

    my $canceled_item = $shipment->search_related('shipment_items',{variant_id => $multi_variant->[0]{variant_id}})->first;
    note("Canceling item ".$canceled_item->id." (".$canceled_item->get_sku.")");
    $canceled_item->update({
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
    });

    my $schema = $self->{schema};
    my $new_variant = $schema->resultset('Public::Variant')->search({
        product_id => $canceled_item->variant->product_id,
        size_id => { '!=' => $canceled_item->variant->size_id },
    })->first;

    $schema->resultset('Public::Quantity')->update_or_create({
        variant_id  => $new_variant->id,
        location_id => $self->{invar_loc}->id,
        channel_id  => $channel->id,
        status_id   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        quantity    => 5,
    });

    my $data={
        $canceled_item->get_inflated_columns,
        variant_id => $new_variant->id,
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED,
        container_id => undef,
    };
    delete $data->{id};
    my $new_item = $shipment->add_to_shipment_items($data);

    push @{$payload->{containers}},{
        container_id => $container_ids[1],
        items => [ {
            sku => $new_variant->sku,
            quantity => 1,
        } ],
    };
    # ok, re-send the shipment_ready
    $wms_to_xt = $self->wms_to_xt;
    $res = $self->{amq}->request(
        $self->{app},
        config_var('WMS_Queues','xt_wms_fulfilment'),
        $payload,
        $header,
    );
    $wms_to_xt->expect_messages({  messages => [ { type => 'shipment_ready' } ] });
    ok( $res->is_success, 'shipment_ready message processed ok' );

    $stock_quantity->{$new_variant->id} = 4;

    $shipment->discard_changes;$canceled_item->discard_changes;$new_item->discard_changes;
    my $untouched_item = $shipment->search_related('shipment_items',{variant_id => $pids->[0]{variant_id}})->first;

    is($canceled_item->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__CANCEL_PENDING, 'cancel pending item in same status');
    is($canceled_item->container_id,$container_ids[0],'cancel pending item in same container')
        or diag 'cancelled item in container ' . $canceled_item->container_id;
    is($self->quantity_for($canceled_item->variant_id,$channel->id),4,'cancel pending item stock not reduced further');

    is($untouched_item->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__PICKED, 'untouched item still picked');
    is($untouched_item->container_id,$container_ids[0],'untouched item in same container');
    is($self->quantity_for($untouched_item->variant_id,$channel->id),4,'untouched item stock not reduced further');

    is($new_item->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__PICKED, 'new item picked');
    is($new_item->container_id,$container_ids[1],'new item in correct container');
    is($self->quantity_for($new_item->variant_id,$channel->id),4,'new item stock reduced');
}

=head2 test_faulty_item_replacement

Check the following scenarios:

    * GOH replacement items go into a new container
    * Pigeonhole replacement items go into the same container
    * Place each item in its own container

=cut

sub test_faulty_item_replacement : Tests {
    my $self = shift;

    for (
        # GOH replacement items go into a new container
        [ GOH => sub {
            my ( $container_id, @items ) = @_;
            return { map {
                $_->get_sku => Test::XT::Data::Container->get_unique_ids
            } @items };
        }, ],
        # pigeonhole replacement items go into the same container
        [ pigeonhole => sub {
            my ( $container_id, @items ) = @_;
            return { map { $_->get_sku => $container_id } @items };
        }, ],
        # Let's place each item in its own container
        [ 'to each item their own container' => sub {
            my ( $container_id, @items ) = @_;
            my @container_ids = (
                $container_id,
                Test::XT::Data::Container->get_unique_ids({how_many => $#items})
            );
            return { map { $items[$_]->get_sku => $container_ids[$_] } 0..$#items };
        }, ],
    ) {
        my ( $test_type, $get_replacement_container ) = @$_;

        subtest "test item replacement for $test_type" => sub {
            my $shipment
                = $self->{framework}->picked_order(products => 2)->{shipment_object};

            my ($item_okay, $item_faulty) = $shipment->shipment_items->all;

            # Store our current quantities so we can test them after receiving the
            # shipment_ready message
            my %quantity_for = map {
                $_->[0] => $self->quantity_for($_->[1]->variant_id, $shipment->get_channel->id)
            } ([$item_okay->id => $item_okay], [$item_faulty->id => $item_faulty]);

            # Simulate item confirmed faulty at packing exception by removing
            # the item from its container info and setting its status back to
            # 'selected'
            $item_faulty->container_id(undef);
            $item_faulty->update_status(
                $SHIPMENT_ITEM_STATUS__SELECTED,
                $APPLICATION_OPERATOR_ID,
                $PACKING_EXCEPTION_ACTION__FAULTY,
            );

            my $sku_container_map = $get_replacement_container->(
                $item_okay->container_id, $item_okay, $item_faulty
            );

            # Prepare our shipment_ready container data
            my $container_data;
            push @{$container_data->{$sku_container_map->{$_}}}, $_
                for keys %$sku_container_map;
            $self->{framework}->flow_wms__send_shipment_ready(
                shipment_id => $shipment->id,
                container => $container_data,
            );

            # 'okay item' started as 'picked'
            # 'replacement item' started as 'selected'
            for (
                [ 'okay item'        => $item_okay, $quantity_for{$item_okay->id} ],
                [ 'replacement item' => $item_faulty, $quantity_for{$item_faulty->id}-1 ],
            ) {
                my ( $item_name, $item, $expected_quantity ) = @$_;
                subtest sprintf("test $item_name (id %i)", $item->id) => sub {
                    $item->discard_changes;
                    is($item->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__PICKED,
                        'should be in "picked" status');
                    is($item->container_id, $sku_container_map->{$item->get_sku},
                        'should be in new container');
                    is($self->quantity_for($item->variant_id,$shipment->get_channel->id),
                        $expected_quantity, 'should have expected quantity');
                };
            }
        };
    }
}
