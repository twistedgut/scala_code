#!/usr/bin/env perl

use NAP::policy "tt",     'test';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use String::Random;

use base 'Test::Class';

use Carp::Always;
use XTracker::Config::Local     qw( config_var );
use XTracker::Constants         qw( :application );
use XTracker::Constants::FromDB qw(
                                    :authorisation_level
                                    :shipment_status
                                    :shipment_item_status
                                    :order_status
                                    :flag
                                );
use XTracker::Database::Shipment        qw( update_shipment_status );
use XTracker::Database::OrderPayment    qw( toggle_payment_fulfilled_flag_and_log );
use Test::XTracker::Mechanize;
use Test::XT::Flow;


sub create_order {
    my ( $self, $args ) = @_;
    my $pids_to_use = $args->{pids_to_use};
    my ($order) = Test::XTracker::Data->apply_db_order({
        pids => $self->{pids}{ $pids_to_use },
        attrs => [ { price => $args->{price} }, ],
        base => {
            tenders => $args->{tenders},
            shipment_status => $SHIPMENT_STATUS__FINANCE_HOLD,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__PICKED,
        },
    });
    note "Order Nr/Id: ".$order->order_nr."/".$order->id;
    note "Shipment Id: ".$order->shipments->first->id;
    $order->shipments->first->renumerations->delete;
    $order->update( { order_status_id => $ORDER_STATUS__CREDIT_HOLD } );
    $order->create_related( 'order_flags', {
                                    flag_id => $FLAG__VIRTUAL_VOUCHER_PAYMENT_FAILURE,
                                } );
    $self->{order_queue} = config_var('Producer::Orders::Update','routes_map')
        ->{$order->channel->web_name};
    return $order;
}

sub startup : Tests( startup => no_plan ) {
    my $test = shift;

    $test->{schema} = Test::XTracker::Data->get_schema;
    $test->{mq} = Test::XTracker::MessageQueue->new;
    my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
        how_many => 1, channel => 'nap',
        phys_vouchers => {
            how_many => 1,
        },
        virt_vouchers => {
            how_many => 1,
        },
    });
    $pids->[2]{assign_code_to_ship_item}    = 1;
    $test->{pids}{virt_vouch_only}          = [ $pids->[2] ];
    $test->{pids}{phys_and_virt_vouchers}   = [ $pids->[1], $pids->[2] ];
    $test->{pids}{mixed}                    = $pids;

    my $framework = Test::XT::Flow->new_with_traits( {
        traits => [
            'Test::XT::Flow::Finance',
        ],
    } );
    $test->{framework} = $framework;
    $test->{mech}      = $framework->mech;

    $test->{framework}->login_with_roles( {
        paths => [
            '/Finance/CreditHold%',
            '/Finance/Order/Accept',
        ],
        main_nav => [
            'Customer Care/Order Search',
        ],
    } );
    Test::XTracker::Data->set_department( $test->{mech}->logged_in_as, 'Finance' );

    $test->{op_id}  = $APPLICATION_OPERATOR_ID;
}

sub test_dispatch_virtual_voucher_only_shipment : Tests {
    my $test = shift;
    my $order       = $test->create_order( { pids_to_use => 'virt_vouch_only' } );
    my $shipment    = $order->shipments->first;
    my $schema      = $test->{schema};
    my $op_id       = $test->{op_id};
    my $order_queue = $test->{order_queue};

    my @items       = $shipment->shipment_items->all;

    dies_ok( sub { $shipment->dispatch_virtual_voucher_only_shipment; },
                    "'dispatch_virtual_voucher_only_shipment' dies with no Operator Id passed" );

    note "Test Shipment is not Dispatched when not correct Conditions";
    $test->{mq}->clear_destination( $order_queue );
    $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__FINANCE_HOLD } );
    cmp_ok( $shipment->dispatch_virtual_voucher_only_shipment( $op_id ), '==', 0,
                            "'dispatch_virtual_voucher_only_shipment' returned FALSE when on Finance Hold" );
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__FINANCE_HOLD,
                            "Shipment Status is still on Finance Hold" );
    foreach ( @items ) {
        $_->discard_changes;
        cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED,
                            "Shipment Item Status is still on Picked" );
    }
    # check no messages sent to the PWS
    $test->{mq}->assert_messages({
        destination => $order_queue,
        assert_count => 0,
    }, "No Order Update AMQ Messages Sent" );

    $test->{mq}->clear_destination( $order_queue );
    $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );
    $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW } );
    cmp_ok( $shipment->dispatch_virtual_voucher_only_shipment( $op_id ), '==', 0,
                            "'dispatch_virtual_voucher_only_shipment' returned FALSE when NOT all items are Picked" );
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING,
                            "Shipment Status is still on Processing" );
    foreach ( @items ) {
        $_->discard_changes;
        cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__NEW,
                            "Shipment Item Status is still on Picked" );
    }
    # check no messages sent to the PWS
    $test->{mq}->assert_messages({
        destination => $order_queue,
        assert_count => 0,
    }, "No Order Update AMQ Messages Sent" );

    note "Test Shipment is Dispacthed when everything is at correct Status";
    $test->{mq}->clear_destination( $order_queue );
    $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED } );
    cmp_ok( $shipment->dispatch_virtual_voucher_only_shipment( $op_id ), '==', 1,
                            "'dispatch_virtual_voucher_only_shipment' returned TRUE when items are Picked and status is Processing" );
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DISPATCHED,
                            "Shipment Status is Dispatched" );
    my @msg_items;
    foreach ( @items ) {
        $_->discard_changes;
        cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED,
                            "Shipment Item Status is Dispatched" );
        cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED } ), '==', 1,
                            "Shipment Item has logged Packed status" );
        push @msg_items, superhashof({
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
            orderItems  => bag(@msg_items),
        }),
    }, "AMQ Dispatch Message to Web-Site OK" );

    # now test with a mixed order that it doesn't dispatch
    $order      = $test->create_order( { pids_to_use => 'mixed' } );
    $shipment   = $order->shipments->first;
    @items      = $shipment->shipment_items->all;
    $test->{mq}->clear_destination( $order_queue );
    $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );
    cmp_ok( $shipment->dispatch_virtual_voucher_only_shipment( $op_id ), '==', 0,
                            "'dispatch_virtual_voucher_only_shipment' returned FALSE when Not Virtual Voucher Only Order" );
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING,
                            "Shipment Status is still on Processing" );
    foreach ( @items ) {
        $_->discard_changes;
        cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED,
                            "Shipment Item Status is still on Picked" );
    }
    # check no messages sent to the PWS
    $test->{mq}->assert_messages({
        destination => $order_queue,
        assert_count => 0,
    }, "No Order Update AMQ Messages Sent" );
}

sub test_update_status_for_virtual_voucher_orders : Tests {
    my $test = shift;
    my $order       = $test->create_order( { pids_to_use => 'virt_vouch_only' } );
    my $shipment    = $order->shipments->first;
    my @items       = $shipment->shipment_items->all;
    my $schema      = $test->{schema};
    my $op_id       = $test->{op_id};
    my $order_queue = $test->{order_queue};

    $schema->txn_do( sub {
            note "Test using Database::Shipment::update_shipment_status";
            $test->{mq}->clear_destination( $order_queue );
            cmp_ok( update_shipment_status( $schema->storage->dbh, $shipment->id, $SHIPMENT_STATUS__PROCESSING, $op_id ), '==', 1,
                            "'update_shipment_status' returned TRUE" );
            $shipment->discard_changes;

            $shipment->discard_changes;
            cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DISPATCHED,
                                    "Shipment Status is Dispatched" );
            foreach ( @items ) {
                $_->discard_changes;
                cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED,
                                    "Shipment Item Status is Dispatched" );
                cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED } ), '==', 1,
                                    "Shipment Item has logged Packed status" );
            }

            $test->{mq}->assert_messages( {
                destination => $order_queue,
                assert_header => superhashof({
                    JMSXGroupID => $order->channel->lc_web_name,
                    type => 'OrderMessage',
                }),
                assert_body => superhashof({
                    orderNumber => $order->order_nr,
                    status      => 'Dispatched',
                }),
            }, "AMQ Dispatch Message to Web-Site OK" );

            $schema->txn_rollback;
        } );

    $shipment->discard_changes;

    $schema->txn_do( sub {
            note "Test using XTracker::Schema::Result::Public::Shipment::update_status";
            $test->{mq}->clear_destination( $order_queue );
            $shipment->update_status( $SHIPMENT_STATUS__PROCESSING, $op_id );
            $shipment->discard_changes;

            cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DISPATCHED,
                                    "Shipment Status is Dispatched" );
            foreach ( @items ) {
                $_->discard_changes;
                cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED,
                                    "Shipment Item Status is Dispatched" );
                cmp_ok( $_->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED } ), '==', 1,
                                    "Shipment Item has logged Packed status" );
            }

            $test->{mq}->assert_messages( {
                destination => $order_queue,
                assert_header => superhashof({
                    JMSXGroupID => $order->channel->lc_web_name,
                    type => 'OrderMessage',
                }),
                assert_body => superhashof({
                    orderNumber => $order->order_nr,
                    status      => 'Dispatched',
                }),
            }, "AMQ Dispatch Message to Web-Site OK" );

            $schema->txn_rollback;
        } );
}

sub test_virtual_voucher_order_only : Tests {
    my $test = shift;
    my $mech        = $test->{mech};
    my $framework   = $test->{framework};

    my $order       = $test->create_order( { pids_to_use => 'virt_vouch_only' } );
    my $order_queue = $test->{order_queue};

    my $shipment= $order->shipments->first;

    # get virtual voucher shipment items
    my @items   = $shipment->shipment_items->all;

    $test->{mq}->clear_destination( $order_queue );       # clear the order queue for the response

    $framework->flow_mech__finance__credit_hold;
    my $found   = $mech->find_xpath('//td[(@class="highlight3") or (@class="highlight4")]/a[@href="/Finance/CreditHold/OrderView?order_id='.$order->id.'"]');
    ok( scalar($found->get_nodelist), $order->id." is in class 'highlight3/4'" );
    $mech->follow_link_ok( { text => $order->order_nr }, "Go to Order View page" );

    # Accecpt the Order
    $mech->follow_link_ok( { text_regex => qr/Accept Order/ }, "Accept the Order" );
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok( qr/Virtual Voucher Only Order was Dispatched/, "Dispatched message shown on page" );

    # check the Shipment Statuses
    my @order_items;
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DISPATCHED,
                    "Shipment Status is 'Dispatched'" );
    # check the order the shipment statuses are in the log
    my @status_logs = $shipment->shipment_status_logs->search( {}, { order_by => 'me.id DESC' } )->all;
    cmp_ok( $status_logs[0]->shipment_status_id, '==', $SHIPMENT_STATUS__DISPATCHED, "Shipment Log 'Dispatch' Status Last" );
    cmp_ok( $status_logs[1]->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING, "Shipment Log 'Processing' Status Second Last" );

    # check Shipment Item Statuses
    foreach ( @items ) {
        $_->discard_changes;
        cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED,
                    "Shipment Item (".$_->id.") Status is 'Dispatched'" );
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

sub test_virtual_voucher_order_only_manual_payment_fulfilled : Tests {
    my $test = shift;
    my $schema      = $test->{schema};
    my $mech        = $test->{mech};

    my $order       = $test->create_order( { pids_to_use => 'virt_vouch_only' } );
    my $order_queue = $test->{order_queue};

    my $shipment= $order->shipments->first;

    my $next_preauth    = Test::XTracker::Data->get_next_preauth( $schema->storage->dbh );

    $order->update( { order_status_id => $ORDER_STATUS__ACCEPTED } );
    $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );
    my $payment = Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref     => $next_preauth,
        preauth_ref => $next_preauth,
    } );

    # get virtual voucher shipment items
    my @items   = $shipment->shipment_items->all;

    $test->{mq}->clear_destination( $order_queue );       # clear the order queue for the response

    cmp_ok( toggle_payment_fulfilled_flag_and_log( $schema, $payment->id, $APPLICATION_OPERATOR_ID, 'Test Reason' ), '==', 1,
                        "Toggle Payment Flag returned TRUE" );

    # check the Shipment Statuses
    my @order_items;
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DISPATCHED,
                    "Shipment Status is 'Dispatched'" );

    # check Shipment Item Statuses
    foreach ( @items ) {
        $_->discard_changes;
        cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED,
                    "Shipment Item (".$_->id.") Status is 'Dispatched'" );
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

sub test_mixed_order : Tests {
    my $test = shift;
    my $mech        = $test->{mech};
    my $framework   = $test->{framework};

    my $order       = $test->create_order( { pids_to_use => 'mixed' } );
    my $order_queue = $test->{order_queue};

    $test->{mq}->clear_destination( $order_queue );       # clear the order queue for the response

    my $shipment= $order->shipments->first;

    # get shipment items
    my @items   = $shipment->shipment_items->all;

    $framework->flow_mech__finance__credit_hold;
    my $found   = $mech->find_xpath('//td[(@class="highlight3") or (@class="highlight4")]/a[@href="/Finance/CreditHold/OrderView?order_id='.$order->id.'"]');
    ok( scalar($found->get_nodelist), $order->id." is in class 'highlight3/4'" );
    $mech->follow_link_ok( { text => $order->order_nr }, "Go to Order View page" );

    # Accecpt the Order
    $mech->follow_link_ok( { text_regex => qr/Accept Order/ }, "Accept the Order" );
    $mech->no_feedback_error_ok;
    $mech->content_unlike( qr/Virtual Voucher Only Order was Dispatched/, "No Dispatched Message shown on Page" );

    # check the shipment item statuses
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING,
                    "Shipment Status is still 'Processing'" );
    foreach ( @items ) {
        $_->discard_changes;
        cmp_ok( $_->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED,
                    "Shipment Item (".$_->id.") Status is still 'Picked'" );
    }

    # check no messages sent to the PWS
    $test->{mq}->assert_messages({
        destination => $order_queue,
        assert_count => 0,
    }, "No Order Update AMQ Messages Sent" );
}

Test::Class->runtests;
