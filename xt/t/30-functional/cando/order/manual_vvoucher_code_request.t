#!/usr/bin/env perl
use NAP::policy "tt", 'test';

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
use XTracker::Database::OrderPayment    qw( toggle_payment_fulfilled_flag_and_log );
use Test::XTracker::Mechanize;
use Test::Exception;

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
    note "Order Nr/Id: ".$order->order_nr."/".$order->id;
    note "Shipment Id: ".$order->shipments->first->id;
    $order->shipments->first->renumerations->delete;
    $self->{order_queue} =  config_var('Producer::Orders::Update','routes_map')
        ->{$order->channel->web_name};

    return $order;
}

sub startup : Tests(startup => 4) {
    my $test = shift;
    $test->{schema} = Test::XTracker::Data->get_schema;
    $test->{mq} = Test::XTracker::MessageQueue->new;
    my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
        how_many => 1, channel => 'nap',
        phys_vouchers => {
            how_many => 1,
        },
        virt_vouchers => {
            how_many => 2,
        },
    });
    $pids->[2]{assign_code_to_ship_item}    = 1;
    $pids->[3]{assign_code_to_ship_item}    = 1;
    $test->{pids}{virt_vouch_only}          = [ $pids->[2], $pids->[3] ];
    $test->{pids}{phys_and_virt_vouchers}   = [ $pids->[1], $pids->[2] ];
    $test->{pids}{mixed}                    = $pids;
    $test->{pids}{normal}                   = [ $pids->[0] ];

    $test->{mech}                           = Test::XTracker::Mechanize->new;
    $test->_setup_app_perms;
    $test->{mech}->do_login;
    $test->{op_id}  = $APPLICATION_OPERATOR_ID;
    $test->{queue}  = '/queue/fulcrum/product';
}

sub test_virtual_voucher_order_only : Tests {
    my $test = shift;
    my $mech        = $test->{mech};

    my $order       = $test->create_order( { pids_to_use => 'virt_vouch_only' } );

    my $shipment= $order->shipments->first;

    # get virtual voucher shipment items
    my @items   = $shipment->shipment_items->search( {}, { order_by => 'me.id ASC' } )->all;

    note "With all Items having Voucher Codes";
    $mech->order_nr( $order->order_nr );
    $mech->get_ok( $mech->order_view_url );
    $mech->content_unlike( qr/Request Virtual Voucher Codes/, "Can't see Request Code button" );

    # clear one of the codes
    note "Clear one Item's Voucher Codes";
    $items[0]->update( { voucher_code_id => undef } );
    $mech->get_ok( $mech->order_view_url );
    $mech->content_like( qr/Request Virtual Voucher Codes/, "Can see Request Code button" );

    # clear both of the codes
    note "Clear all Item's Voucher Codes";
    $items[1]->update( { voucher_code_id => undef } );
    $mech->get_ok( $mech->order_view_url );
    $mech->content_like( qr/Request Virtual Voucher Codes/, "Can see Request Code button" );

    $test->{mq}->clear_destination( $test->{queue} );
    $mech->submit_form_ok( {
        form_name   => 'request_virtual_codes_'.$shipment->id,
        button      => 'submit',
    }, "Request Codes for Virtual Vouchers" );
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok( qr/Virtual Voucher Codes have been Requested/, "Virtual Codes Requested Message Shown" );

    # check message sent to Fulcrum
    $test->{mq}->assert_messages( {
        destination=> $test->{queue},
        assert_header => superhashof({
            type => 'generate_virtual_voucher_code',
        }),
        assert_body => superhashof({
            channel_id  => $order->channel_id,
            shipments   => bag(
                superhashof({
                    shipment_id => $shipment->id,
                    shipment_items  => bag(
                        superhashof({
                            shipment_item_id => $items[0]->id,
                            voucher_pid => $items[0]->get_true_variant->voucher_product_id,
                        }),
                        superhashof({
                            shipment_item_id => $items[1]->id,
                            voucher_pid => $items[1]->get_true_variant->voucher_product_id,
                        }),
                    )
                }),
            ),
        }),
    }, "Check AMQ Message Sent" );
}

sub test_mixed_order : Tests {
    my $test = shift;
    my $mech        = $test->{mech};

    my $order       = $test->create_order( { pids_to_use => 'mixed' } );

    my $shipment= $order->shipments->first;

    # get shipment items
    my @items   = $shipment->shipment_items->search( {}, { order_by => 'me.id ASC' } )->all;

    # get virtual items
    my @virt_items;
    foreach my $item ( @items ) {
        if ( $item->is_virtual_voucher ) {
            push @virt_items, $item;
        }
    }

    note "With all Items having Voucher Codes";
    $mech->order_nr( $order->order_nr );
    $mech->get_ok( $mech->order_view_url );
    $mech->content_unlike( qr/Request Virtual Voucher Codes/, "Can't see Request Code button" );

    # clear one of the codes
    note "Clear one Virtual Item's Voucher Codes";
    $virt_items[0]->update( { voucher_code_id => undef } );
    $mech->get_ok( $mech->order_view_url );
    $mech->content_like( qr/Request Virtual Voucher Codes/, "Can see Request Code button" );

    $test->{mq}->clear_destination( $test->{queue} );
    $mech->submit_form_ok( {
        form_name   => 'request_virtual_codes_'.$shipment->id,
        button      => 'submit',
    }, "Request Codes for Virtual Vouchers" );
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok( qr/Virtual Voucher Codes have been Requested/, "Virtual Codes Requested Message Shown" );

    # check message sent to Fulcrum
    $test->{mq}->assert_messages( {
        destination => $test->{queue},
        assert_header => superhashof({
            type => 'generate_virtual_voucher_code',
        }),
        assert_body => superhashof({
            channel_id  => $order->channel_id,
            shipments   => bag(
                superhashof({
                    shipment_id => $shipment->id,
                    shipment_items  => bag(
                        superhashof({
                            shipment_item_id => $virt_items[0]->id,
                            voucher_pid => $virt_items[0]->get_true_variant->voucher_product_id,
                        }),
                    ),
                }),
            ),
        }),
    }, "Check AMQ Message Sent" );
}

sub test_normal_only : Tests {
    my $test = shift;
    my $mech        = $test->{mech};

    my $order       = $test->create_order( { pids_to_use => 'normal' } );

    $mech->order_nr( $order->order_nr );
    $mech->get_ok( $mech->order_view_url );
    $mech->content_unlike( qr/Request Virtual Voucher Codes/, "Can't see Request Code button" );
}

sub _setup_app_perms {
    my $self    = shift;

    Test::XTracker::Data->set_department('it.god', 'Customer Care');
    Test::XTracker::Data->grant_permissions( 'it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR );
}

Test::Class->runtests;
