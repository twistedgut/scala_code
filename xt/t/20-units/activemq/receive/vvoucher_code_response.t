#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use Test::XTracker::Hacks::isaFunction;

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use String::Random;

use XTracker::Constants         qw( :application );
use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw(
                                    :shipment_status
                                    :shipment_item_status
                                    :order_status
                                    :flag
                                );
use XTracker::Constants::Payment    qw( :psp_return_codes );
use Test::XTracker::Mock::PSP;

use base 'Test::Class';

sub get_voucher_code {
    my $self    = shift;

    my $sr = String::Random->new;
    my $c = 'GC'.$sr->randregex('[A-Z]{7}');

    return $c;
}

# check that the voucher codes requested
# were created for the right Voucher and activated
# and assigned to the correct shipment item
sub check_voucher_code_ok {
    my ( $self, $items )    = @_;

    note "Checking Voucher Codes created and assigned";
    my $schema  = $self->{schema};
    foreach my $item ( @{ $items } ) {
        note "Voucher Code: ".$item->{voucher_code}.", Voucher PID: ".$item->{voucher_pid}.", Shipment Item: ".$item->{shipment_item_id};
        my $vcode   = $schema->resultset('Voucher::Code')->find( { code => $item->{voucher_code} } );
        isa_ok( $vcode, 'XTracker::Schema::Result::Voucher::Code', "Voucher Code created" );
        cmp_ok( $vcode->voucher_product_id, '==', $item->{voucher_pid}, "Voucher Code created for correct PID" );
        ok( defined $vcode->assigned, "Voucher Code has been activated" );
        my $ship_item   = $schema->resultset('Public::ShipmentItem')->find( $item->{shipment_item_id} );
        cmp_ok( $ship_item->voucher_code_id, '==', $vcode->id, "Voucher Code assigned to correct Shipment Item" );
    }

    return;
}

sub create_order {
    my ( $self, $args ) = @_;
    my $pids_to_use = $args->{pids_to_use};
    my ($order) = Test::XTracker::Data->apply_db_order({
        pids => $self->{pids}{ $pids_to_use },
        attrs => [ { price => $args->{price} }, ],
        base => {
            tenders => $args->{tenders},
            shipment_status => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        },
    });
    $order->shipments->first->renumerations->delete;
    $self->{mq}->clear_destination( $self->{queue_name} );
    return $order;
}

sub startup : Tests(startup => 3) {
    my $test = shift;
    $test->{schema} = Test::XTracker::Data->get_schema;
    ($test->{mq},$test->{app}) = Test::XTracker::MessageQueue->new_with_app;
    $test->{queue_name} = '/queue/'.config_var('DistributionCentre', 'name').'/product';
    $test->{mq}->clear_destination( $test->{queue_name} );
    my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
        how_many => 1, channel => 'nap',
        phys_vouchers => {
            how_many => 1,
        },
        virt_vouchers => {
            how_many => 2,
        },
    });
    $test->{pids}{virt_vouch_only}          = [ $pids->[2] ];
    $test->{pids}{two_virt_vouch_only}      = [ $pids->[2], $pids->[3] ];
    $test->{pids}{phys_and_virt_vouchers}   = [ $pids->[1], $pids->[2] ];
    $test->{pids}{mixed}                    = $pids;
}

sub test_virtual_voucher_code_response_for_virtual_voucher_order_only : Tests {
    my $test = shift;
    my $order       = $test->create_order( { pids_to_use => 'virt_vouch_only' } );
    my $order_queue = config_var('Producer::Orders::Update','routes_map')
        ->{$order->channel->web_name};

    my $shipment= $order->shipments->first;
    cmp_ok( $shipment->is_virtual_voucher_only, '==', 1, "'shipment->is_virtual_voucher_only' returns TRUE" );

    # get virtual voucher shipment items
    my @items   = $shipment->shipment_items->all;
    my @virt_items;
    my @msg_ship_items;
    foreach ( @items ) {
        if ( $_->voucher_variant_id &&
                !$_->get_true_variant->product->is_physical ) {
            push @msg_ship_items, {
                    shipment_item_id=> $_->id,
                    voucher_pid     => $_->get_true_variant->product_id,
                    voucher_code    => $test->get_voucher_code(),
                };
            push @virt_items, $_;
        }
    }

    $test->{mq}->clear_destination( $order_queue );       # clear the order queue for the response
    my $msg_body    = {
        #'@type'     => 'assign_virtual_voucher_code_to_shipment',
            channel_id  => $order->channel_id,
            shipments   => [
                {
                    shipment_id     => $shipment->id,
                    shipment_items  => \@msg_ship_items,
                },
            ],
        };
    my $res = $test->{mq}->request(
        $test->{app},
        $test->{queue_name},
        $msg_body,
        { type => 'assign_virtual_voucher_code_to_shipment' },
    );
    ok( $res->is_success, "Virtual Voucher Codes from Fulcrum" );

    $test->check_voucher_code_ok( \@msg_ship_items );

    # check the shipment item statuses
    my @order_items;
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DISPATCHED,
                    "Shipment Status is 'Dispatched'" );
    foreach ( @items ) {
        $_->discard_changes;
        cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED,
                    "Shipment Item (".$_->id.") Status is 'Dispatched'" );
        cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED } ), '==', 1,
                                    "Virtual Shipment Item 'Selected' Status is also logged" );
        cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED } ), '==', 1,
                                    "Virtual Shipment Item 'Picked' Status is also logged" );
        cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED } ), '==', 1,
                                    "Virtual Shipment Item 'Packed' Status is also logged" );
        # make up order items for AMQ message
        push @order_items, superhashof({
                sku         => $_->get_true_variant->sku,
                xtLineItemId=> $_->id,
                status      => 'Dispatched',
                voucherCode => $_->voucher_code->code,
            });
    }

    # check a message was sent to the Web-Site
    $test->{mq}->assert_messages( {
        destination => $order_queue,
        assert_header => superhashof({
            JMSXGroupID => $order->channel->lc_web_name,
            type => 'OrderMessage',
        }),
        assert_body => superhashof({
            orderNumber => $order->order_nr,
            status      => 'Dispatched',
            orderItems  => bag(@order_items),
        }),
    }, "AMQ Dispatch Message to Web-Site OK" );
}

sub test_virtual_voucher_code_multiple_response : Tests {
    my $test = shift;
    my $order       = $test->create_order( { pids_to_use => 'two_virt_vouch_only' } );
    my $order_queue = config_var('Producer::Orders::Update','routes_map')
        ->{$order->channel->web_name};

    my $shipment= $order->shipments->first;

    # get virtual voucher shipment items
    my @items   = $shipment->shipment_items->search( {}, { order_by => 'me.id ASC' } )->all;

    note "Make a Request for only one of the Shipment Items";
    my @msg_ship_items;
    my $orig_vcode  = $test->get_voucher_code();
    push @msg_ship_items, {
            shipment_item_id=> $items[0]->id,
            voucher_pid     => $items[0]->get_true_variant->product_id,
            voucher_code    => $orig_vcode,
        };

    $test->{mq}->clear_destination( $order_queue );       # clear the order queue for the response
    my $msg_body    = {
            #'@type'     => 'assign_virtual_voucher_code_to_shipment',
            channel_id  => $order->channel_id,
            shipments   => [
                {
                    shipment_id     => $shipment->id,
                    shipment_items  => \@msg_ship_items,
                },
            ],
        };
    my $res = $test->{mq}->request(
        $test->{app},
        $test->{queue_name},
        $msg_body,
        { type => 'assign_virtual_voucher_code_to_shipment' },
    );
    ok( $res->is_success, "Virtual Voucher Codes from Fulcrum" );

    $test->check_voucher_code_ok( \@msg_ship_items );

    # check the shipment item statuses
    my @order_items;
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING,
                    "Shipment Status is still 'Processing'" );
    foreach ( ( $items[0] ) ) {
        $_->discard_changes;
        cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED,
                    "Shipment Item (".$_->id.") Status is 'Picked'" );
        cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED } ), '==', 1,
                                    "Virtual Shipment Item 'Selected' Status is also logged" );
        cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED } ), '==', 1,
                                    "Virtual Shipment Item 'Picked' Status is also logged" );
    }

    # check no messages sent to the PWS
    $test->{mq}->assert_messages({
        destination => $order_queue,
        assert_count => 0,
    }, "No Order Update AMQ Messages Sent" );

    note "Make Second request with Both Items, first Item should not be Updated with a new Code";
    $test->{mq}->clear_destination( $test->{queue_name} );
    @msg_ship_items = ();
    foreach my $item ( @items ) {
        push @msg_ship_items, {
                shipment_item_id=> $item->id,
                voucher_pid     => $item->get_true_variant->product_id,
                voucher_code    => $test->get_voucher_code(),
            };
    }

    $test->{mq}->clear_destination( $order_queue );       # clear the order queue for the response
    $msg_body    = {
            #'@type'     => 'assign_virtual_voucher_code_to_shipment',
            channel_id  => $order->channel_id,
            shipments   => [
                {
                    shipment_id     => $shipment->id,
                    shipment_items  => \@msg_ship_items,
                },
            ],
        };
    $res = $test->{mq}->request(
        $test->{app},
        $test->{queue_name},
        $msg_body,
        { type => 'assign_virtual_voucher_code_to_shipment' },
    );
    ok( $res->is_success, "Virtual Voucher Codes from Fulcrum" );

    $test->check_voucher_code_ok( [ $msg_ship_items[1] ] );
    ok( !defined $test->{schema}->resultset('Voucher::Code')->find( { code => $msg_ship_items[0]->{voucher_code} } ),
                                    "New Voucher Code for 1st Item NOT Created" );

    # check the shipment item statuses
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DISPATCHED,
                    "Shipment Status is 'Dispatched'" );
    my $count   = 0;
    foreach ( @items ) {
        $_->discard_changes;
        cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED,
                    "Shipment Item (".$_->id.") Status is 'Dispatched'" );
        cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED } ), '==', 1,
                                    "Virtual Shipment Item 'Selected' Status is logged once" );
        cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED } ), '==', 1,
                                    "Virtual Shipment Item 'Picked' Status is logged once" );
        cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } ), '==', 1,
                                    "Virtual Shipment Item 'Dispatched' Status is logged once" );

        if ( $count == 0 ) {
            is( $_->voucher_code->code, $orig_vcode, "Original Voucher Code for 1st Item Unchanged" );
        }

        # make up order items for AMQ message
        push @order_items, superhashof({
                sku         => $_->get_true_variant->sku,
                xtLineItemId=> $_->id,
                status      => 'Dispatched',
                voucherCode => $_->voucher_code->code,
            });

        $count++;
    }

    # check a message was sent to the Web-Site
    $test->{mq}->assert_messages( {
        destination => $order_queue,
        assert_header => superhashof({
            JMSXGroupID => $order->channel->lc_web_name,
            type => 'OrderMessage',
        }),
        assert_body => superhashof({
            orderNumber => $order->order_nr,
            status      => 'Dispatched',
            orderItems  => bag(@order_items),
        }),
    }, "AMQ Dispatch Message to Web-Site OK" );
}

sub test_virtual_voucher_order_only_fails_payment : Tests {
    my $test = shift;
    my $order       = $test->create_order( { pids_to_use => 'virt_vouch_only' } );
    my $order_queue = config_var('Producer::Orders::Update','routes_map')
        ->{$order->channel->web_name};

    my $next_preauth    = Test::XTracker::Data->get_next_preauth( $test->{schema}->storage->dbh );

    # create an 'orders.payment' record
    Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref     => $next_preauth,
        preauth_ref => $next_preauth,
    } );

    Test::XTracker::Mock::PSP->set_settle_payment_return_code( $PSP_RETURN_CODE__BANK_REJECT );

    my $shipment= $order->shipments->first;

    # get virtual voucher shipment items
    my @items   = $shipment->shipment_items->all;
    my @virt_items;
    my @msg_ship_items;
    foreach ( @items ) {
        if ( $_->voucher_variant_id &&
                !$_->get_true_variant->product->is_physical ) {
            push @msg_ship_items, {
                    shipment_item_id=> $_->id,
                    voucher_pid     => $_->get_true_variant->product_id,
                    voucher_code    => $test->get_voucher_code(),
                };
            push @virt_items, $_;
        }
    }

    $test->{mq}->clear_destination( $order_queue );       # clear the order queue for the response
    my $msg_body    = {
            #'@type'     => 'assign_virtual_voucher_code_to_shipment',
            channel_id  => $order->channel_id,
            shipments   => [
                {
                    shipment_id     => $shipment->id,
                    shipment_items  => \@msg_ship_items,
                },
            ],
        };
    my $res = $test->{mq}->request(
        $test->{app},
        $test->{queue_name},
        $msg_body,
        { type => 'assign_virtual_voucher_code_to_shipment' },
    );
    ok( $res->is_success, "Virtual Voucher Codes from Fulcrum" );

    $test->check_voucher_code_ok( \@msg_ship_items );

    # check the order & shipment item statuses
    my @order_items;
    $shipment->discard_changes;
    $order->discard_changes;
    cmp_ok( $order->order_status_id, '==', $ORDER_STATUS__CREDIT_HOLD,
                    "Order Status is 'Credit Hold'" );
    cmp_ok( $order->order_flags->count( { flag_id => $FLAG__VIRTUAL_VOUCHER_PAYMENT_FAILURE } ), '>', 0,
                    "Order Finance Flag Set for 'Virtual Voucher Payment Issue'" );
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__FINANCE_HOLD,
                    "Shipment Status is 'Finance Hold'" );
    foreach ( @items ) {
        $_->discard_changes;
        cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED,
                    "Shipment Item (".$_->id.") Status is 'Picked'" );
        cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED } ), '==', 1,
                                    "Virtual Shipment Item 'Selected' Status is also logged" );
    }

    # check no messages sent to the PWS
    $test->{mq}->assert_messages({
        destination => $order_queue,
        assert_count => 0,
    }, "No Order Update AMQ Messages Sent" );
}

sub test_virtual_voucher_code_response_for_physical_and_virtual_voucher_order : Tests {
    my $test = shift;
    my $order   = $test->create_order( { pids_to_use => 'phys_and_virt_vouchers' } );

    my $shipment= $order->shipments->first;
    cmp_ok( $shipment->is_virtual_voucher_only, '==', 0, "'shipment->is_virtual_voucher_only' returns FALSE" );

    # get virtual voucher shipment items
    my @items   = $shipment->shipment_items->all;
    my @virt_items;
    my @othr_items;
    my @msg_ship_items;
    foreach ( @items ) {
        if ( $_->voucher_variant_id &&
                !$_->get_true_variant->product->is_physical ) {
            push @msg_ship_items, {
                    shipment_item_id=> $_->id,
                    voucher_pid     => $_->get_true_variant->product_id,
                    voucher_code    => $test->get_voucher_code(),
                };
            push @virt_items, $_;
        }
        else {
            push @othr_items, $_;
        }
    }

    my $msg_body    = {
            #'@type'     => 'assign_virtual_voucher_code_to_shipment',
            channel_id  => $order->channel_id,
            shipments   => [
                {
                    shipment_id     => $shipment->id,
                    shipment_items  => \@msg_ship_items,
                },
            ],
        };
    my $res = $test->{mq}->request(
        $test->{app},
        $test->{queue_name},
        $msg_body,
        { type => 'assign_virtual_voucher_code_to_shipment' },
    );
    ok( $res->is_success, "Virtual Voucher Codes from Fulcrum" );

    $test->check_voucher_code_ok( \@msg_ship_items );

    # check the shipment item statuses
    my @order_items;
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING,
                    "Shipment Status is still 'Processing'" );
    foreach ( @items ) {
        $_->discard_changes;
        if ( $_->is_virtual_voucher ) {
            cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED,
                        "Virtual Shipment Item (".$_->id.") Status is 'Picked'" );
            cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED } ), '==', 1,
                                        "Virtual Shipment Item 'Selected' Status is also logged" );
        }
        else {
            cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__NEW,
                        "Physical Shipment Item (".$_->id.") Status is still 'New'" );
        }
    }
}

sub test_virtual_voucher_code_response_for_mixed_order : Tests {
    my $test = shift;
    my $order   = $test->create_order( { pids_to_use => 'mixed' } );

    my $shipment= $order->shipments->first;
    cmp_ok( $shipment->is_virtual_voucher_only, '==', 0, "'shipment->is_virtual_voucher_only' returns FALSE" );

    # get virtual voucher shipment items
    my @items   = $shipment->shipment_items->all;
    my @virt_items;
    my @othr_items;
    my @msg_ship_items;
    foreach ( @items ) {
        if ( $_->voucher_variant_id &&
                !$_->get_true_variant->product->is_physical ) {
            push @msg_ship_items, {
                    shipment_item_id=> $_->id,
                    voucher_pid     => $_->get_true_variant->product_id,
                    voucher_code    => $test->get_voucher_code(),
                };
            push @virt_items, $_;
        }
        else {
            push @othr_items, $_;
        }
    }

    my $msg_body    = {
            #'@type'     => 'assign_virtual_voucher_code_to_shipment',
            channel_id  => $order->channel_id,
            shipments   => [
                {
                    shipment_id     => $shipment->id,
                    shipment_items  => \@msg_ship_items,
                },
            ],
        };
    my $res = $test->{mq}->request(
        $test->{app},
        $test->{queue_name},
        $msg_body,
        { type => 'assign_virtual_voucher_code_to_shipment' },
    );
    ok( $res->is_success, "Virtual Voucher Codes from Fulcrum" );

    $test->check_voucher_code_ok( \@msg_ship_items );

    # check the shipment item statuses
    my @order_items;
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING,
                    "Shipment Status is still 'Processing'" );
    foreach ( @items ) {
        $_->discard_changes;
        if ( $_->is_virtual_voucher ) {
            cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED,
                        "Virtual Shipment Item (".$_->id.") Status is 'Picked'" );
            cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED } ), '==', 1,
                                        "Virtual Shipment Item 'Selected' Status is also logged" );
        }
        else {
            cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__NEW,
                        "Physical Shipment Item (".$_->id.") Status is still 'New'" );
        }
    }
}

sub test_virtual_voucher_code_with_cancelled_physical_items : Tests {
    my $test = shift;
    my $order       = $test->create_order( { pids_to_use => 'mixed' } );
    my $order_queue = config_var('Producer::Orders::Update','routes_map')
        ->{$order->channel->web_name};

    my $shipment= $order->shipments->first;
    cmp_ok( $shipment->is_virtual_voucher_only, '==', 0, "'shipment->is_virtual_voucher_only' returns FALSE" );

    # get virtual voucher shipment items
    my @items   = $shipment->shipment_items->all;
    my @virt_items;
    my %othr_items;
    my @msg_ship_items;
    foreach ( @items ) {
        if ( $_->voucher_variant_id &&
                !$_->get_true_variant->product->is_physical ) {
            push @msg_ship_items, {
                    shipment_item_id=> $_->id,
                    voucher_pid     => $_->get_true_variant->product_id,
                    voucher_code    => $test->get_voucher_code(),
                };
            push @virt_items, $_;
        }
    }

    my $msg_body    = {
            #'@type'     => 'assign_virtual_voucher_code_to_shipment',
            channel_id  => $order->channel_id,
            shipments   => [
                {
                    shipment_id     => $shipment->id,
                    shipment_items  => \@msg_ship_items,
                },
            ],
        };
    my $res = $test->{mq}->request(
        $test->{app},
        $test->{queue_name},
        $msg_body,
        { type => 'assign_virtual_voucher_code_to_shipment' },
    );
    ok( $res->is_success, "Virtual Voucher Codes from Fulcrum" );

    $test->check_voucher_code_ok( \@msg_ship_items );

    # check the shipment item statuses
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING,
                    "Shipment Status is still 'Processing'" );
    foreach ( @items ) {
        $_->discard_changes;
        if ( $_->is_virtual_voucher ) {
            cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED,
                        "Virtual Shipment Item (".$_->id.") Status is 'Picked'" );
            cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED } ), '==', 1,
                                        "Virtual Shipment Item 'Selected' Status is also logged" );
        }
        else {
            cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__NEW,
                        "Physical Shipment Item (".$_->id.") Status is still 'New'" );

            # cancel Physical Items for next test
            if ( $_->voucher_variant_id ) {
                $_->update_status( $SHIPMENT_ITEM_STATUS__CANCEL_PENDING, $APPLICATION_OPERATOR_ID );
                $othr_items{ $_->id }   = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING;
            }
            else {
                $_->update_status( $SHIPMENT_ITEM_STATUS__CANCELLED, $APPLICATION_OPERATOR_ID );
                $othr_items{ $_->id }   = $SHIPMENT_ITEM_STATUS__CANCELLED;
            }
        }
    }

    cmp_ok( $shipment->is_virtual_voucher_only, '==', 1, "'shipment->is_virtual_voucher_only' returns TRUE now Cancelled all Physical Goods" );

    # now dispatch the order after the canellations
    $shipment->discard_changes;
    $test->{mq}->clear_destination( $order_queue );       # clear the order queue for the response
    $shipment->dispatch_virtual_voucher_only_shipment( $APPLICATION_OPERATOR_ID );

    # check the shipment item statuses
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DISPATCHED,
                    "Shipment Status is 'Dispatched'" );
    my @order_items;
    foreach ( @items ) {
        $_->discard_changes;
        if ( $_->is_virtual_voucher ) {
            cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED,
                        "Virtual Shipment Item (".$_->id.") Status is 'Dispatched'" );
            cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } ), '==', 1,
                                        "Virtual Shipment Item 'Dispatched' Status is logged once" );
            # make up order items for AMQ message
            push @order_items, superhashof({
                    sku         => $_->get_true_variant->sku,
                    xtLineItemId=> $_->id,
                    status      => 'Dispatched',
                    voucherCode => $_->voucher_code->code,
                });
        }
        else {
            cmp_ok( $_->shipment_item_status_id, '==', $othr_items{ $_->id }, "Physical Shipment Item Status hasn't changed" );
            # make up order items for AMQ message
            push @order_items, superhashof({
                    sku         => $_->get_true_variant->sku,
                    xtLineItemId=> $_->id,
                    status      => $_->shipment_item_status->status,
                });
        }
    }

    # check a message was sent to the Web-Site
    $test->{mq}->assert_messages( {
        destination => $order_queue,
        assert_header => superhashof({
            JMSXGroupID => $order->channel->lc_web_name,
            type => 'OrderMessage',
        }),
        assert_body => superhashof({
            orderNumber => $order->order_nr,
            status      => 'Dispatched',
            orderItems  => bag(@order_items),
        }),
    }, "AMQ Dispatch Message to Web-Site OK" );
}

Test::Class->runtests;
