#!/usr/bin/env perl

use NAP::policy "tt",     'test';


use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local qw/config_var/;

use XTracker::Constants::FromDB qw( :pre_order_status :pre_order_note_type :pre_order_item_status );
use XTracker::Constants         qw( :application );
use XTracker::Utilities qw( as_zulu );

use Encode;

my $amq = Test::XTracker::MessageQueue->new;
my $schema  = Test::XTracker::Data->get_schema;
my $factory = $amq->producer;

isa_ok( $amq, 'Test::XTracker::MessageQueue' );
isa_ok( $schema, 'XTracker::Schema' );
isa_ok( $factory, 'Net::Stomp::Producer' );

my $channel_rs = $schema->resultset('Public::Channel');

my $channels = $channel_rs->get_channels();

my $msg_type = 'XT::DC::Messaging::Producer::PreOrder::Update';

CHANNEL:
foreach my $channel ( values %$channels ) {
    my $queue = config_var('Producer::PreOrder::Update','routes_map')->{$channel->{web_name}};

    my $new_customer    = Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->{id} } );

    my $preorder = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
        channel  => $new_customer->channel,
        customer => $new_customer,
    } );

    if (!$queue) {
        note "Testing that no message is sent for channel ".$channel->{web_name};

        $amq->clear_destination;

        lives_ok {
            $factory->transform_and_send(
                $msg_type,
                {
                    preorder => $preorder,
                    update_reason => 'new',
                },
            )
        }
            "Sending to wrong channel does not die";

        $amq->assert_messages({
            assert_count => 0,
        },'No message sent');

        next CHANNEL;
    }

    note "Testing AMQ message type: $msg_type into queue: $queue";

    my $data = {
        preorder => $preorder,
        update_reason => 'new',
    };

    my $payment = $preorder->pre_order_payment;

    my $msg_body = _create_message_body( $preorder );

    $amq->clear_destination( $queue );

    lives_ok {
        $factory->transform_and_send(
            $msg_type,
            $data,
        )
    }
    "Can send valid new message";

    $amq->assert_messages({
        destination => $queue,
        assert_header => superhashof({
            type => 'PreOrderUpdate',
        }),
        assert_body => superhashof($msg_body),
    }, 'Message contains the correct new pre-order data');

    $amq->clear_destination( $queue );

    $msg_body->{update_reason} = 'updated';

    $data = {
        preorder => $preorder,
    };

    lives_ok {
        $factory->transform_and_send(
            $msg_type,
            $data,
        )
    }
    "Can send valid update message";

    $amq->assert_messages({
        destination => $queue,
        assert_header => superhashof({
            type => 'PreOrderUpdate',
        }),
        assert_body => superhashof($msg_body),
    }, 'Message contains the correct updated pre-order data');

    $amq->clear_destination( $queue );

    my $note = 'Delivery to Number One, London';

    $preorder->pre_order_notes->create( { note_type_id => $PRE_ORDER_NOTE_TYPE__SHIPMENT_ADDRESS_CHANGE,
                                          note         => $note,
                                          operator_id  => $APPLICATION_OPERATOR_ID } );

    $msg_body->{comment} = "There are special delivery instructions for this pre-order." ;

    $data = {
        preorder => $preorder,
    };

    lives_ok {
        $factory->transform_and_send(
            $msg_type,
            $data,
        )
    }
    "Can send valid address-change message";

    $amq->assert_messages({
        destination => $queue,
        assert_header => superhashof({
            type => 'PreOrderUpdate',
        }),
        assert_body => superhashof($msg_body),
    }, 'Message contains the correct pre-order address-change data' );

    $amq->clear_destination( $queue );

    my $idx = 0;

    foreach my $cancelled_item ( $preorder->pre_order_items->order_by_id->all ) {
        # knock out each item in turn

        $cancelled_item->update_status( $PRE_ORDER_ITEM_STATUS__CANCELLED );

        $msg_body->{items}->[$idx]->{status}= 'Cancelled';
        $msg_body->{total_value}            = $preorder->total_uncancelled_value;

        $data = {
            preorder => $preorder->discard_changes,
        };

        lives_ok {
            $factory->transform_and_send(
                $msg_type,
                $data,
            )
        }
        "Can send valid item cancellation message";

        $amq->assert_messages({
            destination => $queue,
            assert_header => superhashof({
                type => 'PreOrderUpdate',
            }),
            assert_body => superhashof($msg_body),
        }, 'Message contains the correct number of cancelled pre-order items ('.++$idx.')' );

        $amq->clear_destination( $queue );
    }

    $preorder->update_status( $PRE_ORDER_STATUS__CANCELLED );

    $msg_body->{status}     = 'Cancelled';
    $msg_body->{total_value}= $preorder->total_uncancelled_value;

    $data = {
        preorder => $preorder->discard_changes,
    };

    lives_ok {
        $factory->transform_and_send(
            $msg_type,
            $data,
        )
    }
    "Can send valid cancellation message";

    $amq->assert_messages({
        destination => $queue,
        assert_header => superhashof({
            type => 'PreOrderUpdate',
        }),
        assert_body => superhashof($msg_body),
    }, 'Message contains the cancelled pre-order' );

    $amq->clear_destination( $queue );


    #
    # now send messages when there are Orders linked to the Pre-Order
    #

    my $order = Test::XTracker::Data::PreOrder->create_order_linked_to_pre_order( {
        channel  => $new_customer->channel,
        customer => $new_customer,
    } );
    $preorder = $order->get_preorder;

    $msg_body   = _create_message_body( $preorder, 'updated' );

    $data = {
        preorder => $preorder,
    };

    lives_ok {
        $factory->transform_and_send(
            $msg_type,
            $data,
        )
    }
    "Can send valid message when some Pre-Order Items are linked to an Order";

    $amq->assert_messages({
        destination => $queue,
        assert_header => superhashof({
            type => 'PreOrderUpdate',
        }),
        assert_body => superhashof($msg_body),
    }, 'Message contains the correct pre-order data' );

    $amq->clear_destination( $queue );

    my @non_exported_items  = $preorder->pre_order_items->complete->all;
    foreach my $preord_item ( @non_exported_items ) {
        $preord_item->update( { pre_order_item_status_id => $PRE_ORDER_ITEM_STATUS__EXPORTED } );
    }
    $preorder->update( { pre_order_status_id => $PRE_ORDER_STATUS__EXPORTED } );

    $msg_body   = _create_message_body( $preorder->discard_changes, 'updated' );

    $data = {
        preorder => $preorder,
    };

    lives_ok {
        $factory->transform_and_send(
            $msg_type,
            $data,
        )
    }
    "Can send valid message when some Pre-Order Items are Exported but don't yet have an Order";

    $amq->assert_messages({
        destination => $queue,
        assert_header => superhashof({
            type => 'PreOrderUpdate',
        }),
        assert_body => superhashof($msg_body),
    }, 'Message contains the correct pre-order data' );

    $amq->clear_destination( $queue );

    # create another Order with the Remaining Pre-Order Items
    my $order_hash;
    ( $order, $order_hash ) = Test::XTracker::Data->create_db_order( {
                                        pids => [
                                            map { { sku => $_->variant->sku } } @non_exported_items,
                                        ],
                                } );
    # link the Order to a Pre-Order and each Item to its Reservation
    $order->create_related('link_orders__pre_orders', { pre_order_id => $preorder->id } );
    my $shipment    = $order->get_standard_class_shipment;
    foreach my $preord_item ( @non_exported_items ) {
        my $ship_item   = $shipment->shipment_items
                                    ->search( { variant_id => $preord_item->variant_id } )->first;
        $ship_item->create_related('link_shipment_item__reservations', {
                                                            reservation_id => $preord_item->reservation_id,
                                                        } );
    }

    $msg_body   = _create_message_body( $preorder->discard_changes, 'updated' );

    $data = {
        preorder => $preorder,
    };

    lives_ok {
        $factory->transform_and_send(
            $msg_type,
            $data,
        )
    }
    "Can send valid message when Pre-Order Items are linked to different Orders";

    $amq->assert_messages({
        destination => $queue,
        assert_header => superhashof({
            type => 'PreOrderUpdate',
        }),
        assert_body => superhashof($msg_body),
    }, 'Message contains the correct pre-order data' );
    $amq->clear_destination( $queue );


    #
    # Create a Pre-Order with a Discount and test the 'comments' are filled in.
    #

    my $operator = $schema->resultset('Public::Operator')->find( $APPLICATION_OPERATOR_ID );
    $preorder = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
        discount_percentage => 15,
        discount_operator   => $operator,
    } );

    $msg_body = _create_message_body( $preorder->discard_changes, 'updated' );
    $msg_body->{comment} = re( qr/15[\.0-9]*% discount/i );

    $data = {
        preorder => $preorder,
    };

    lives_ok {
        $factory->transform_and_send(
            $msg_type,
            $data,
        )
    }
    "Can send valid message when Pre-Order has a Discount";

    $amq->assert_messages({
        destination => $queue,
        assert_header => superhashof({
            type => 'PreOrderUpdate',
        }),
        assert_body => superhashof($msg_body),
    }, 'Message contains the correct pre-order data' );
    $amq->clear_destination( $queue );
}

done_testing;

#---------------------------------------------------------------------------------

sub _create_message_body {
    my ( $preorder, $reason )   = @_;

    my $payment = $preorder->pre_order_payment;

    my $msg_body = {
        channel => $preorder->channel->web_name,
        update_reason => $reason || 'new',
        customer_number => $preorder->customer->is_customer_number,
        preorder_number => $preorder->pre_order_number,
        status => $preorder->pre_order_status->status,
        delivery_info => '',
        currency => $preorder->currency->currency,
        total_value => $preorder->total_uncancelled_value,
        created => as_zulu($preorder->created),
        payment => {
            preauth_reference => $payment->preauth_ref,
            psp_reference     => $payment->psp_ref,
        },
        items => [
        ]
    };

    foreach my $i ( $preorder->pre_order_items->order_by_id->all ) {
        my $v = $i->variant;
        my $p = $v->product;

        my $order_nr;
        if ( my $link_item = $i->reservation->link_shipment_item__reservations->first ) {
            $order_nr   = $link_item
                            ->shipment_item
                                ->shipment
                                    ->order
                                        ->order_nr;
        }

        push @{$msg_body->{items}}, {
            description => $p->preorder_name,
            sku => $v->sku,
            colour => $p->colour->colour,
            size => $v->designer_size->size,
            price => $i->unit_price,
            tax => $i->tax,
            duty => $i->duty,
            item_total => ( $i->unit_price + $i->tax + $i->duty ),
            status => $i->pre_order_item_status->status,
            ( $order_nr ? ( order_number => $order_nr ) : () ),
        };
    }

    return $msg_body;
}
