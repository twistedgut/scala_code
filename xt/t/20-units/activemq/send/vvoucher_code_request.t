#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::LoadTestConfig;
use Carp::Always;

use Test::XTracker::MessageQueue;;
use Test::XTracker::Data;
use String::Random;

use base 'Test::Class';

sub create_voucher_code {
    my ( $self, $voucher ) = @_;

    my $sr = String::Random->new;
    my $c = 'SCR-'.$sr->randregex('[A-Z]{8}');
    return $voucher->add_code($c);
}

sub create_order {
    my ( $self, $args ) = @_;
    my ( $channel, $pids ) = Test::XTracker::Data->grab_products({
        how_many => 1, channel => 'nap',
        phys_vouchers => {
            how_many => 1,
        },
        virt_vouchers => {
            how_many => 2,
        },
    });
    my ($order) = Test::XTracker::Data->apply_db_order({
        pids => $pids,
        attrs => [ { price => $args->{price} }, ],
        base => {
            tenders => $args->{tenders},
        },
    });
    $self->{pids}   = $pids;
    return $order;
}

sub setup : Test(setup) {
    my $test = shift;
    $test->{sender} = Test::XTracker::MessageQueue->new;
    $test->{queue_name} = '/queue/fulcrum/product';
    $test->{sender}->clear_destination( $test->{queue_name} );
}

sub test_virtual_voucher_code_request : Tests {
    my $test = shift;
    my $order   = $test->create_order();

    my $shipment= $order->shipments->first;

    # get virtual voucher shipment items
    my @items   = $shipment->shipment_items->all;
    my @virt_items;
    my @msg_ship_items;
    foreach ( @items ) {
        if ( $_->voucher_variant_id &&
                !$_->get_true_variant->product->is_physical ) {
            push @msg_ship_items, {
                    shipment_item_id => $_->id,
                    voucher_pid => $_->get_true_variant->product_id,
                };
            push @virt_items, $_;
        }
    }

    my $msg_body = {
        channel_id  => $order->channel_id,
        shipments   => [
            {
                shipment_id     => $shipment->id,
                shipment_items  => bag(@msg_ship_items),
            },
        ],
    };

    # Link order's tenders to renumeration
    $test->{sender}->transform_and_send( 'XT::DC::Messaging::Producer::Order::VirtualVoucherCode', $shipment );
    $test->{sender}->assert_messages( {
        destination => $test->{queue_name},
        assert_header => superhashof({
            type => 'generate_virtual_voucher_code',
        }),
        assert_body => superhashof($msg_body),
    }, 'Request Virtual Voucher Code for all Virtual Items' );

    # assign a code to one of the virtual voucher shipment items
    $virt_items[0]->update( { voucher_code_id => $test->create_voucher_code( $virt_items[0]->get_true_variant->product )->id } );
    # remove that item from the expected message
    shift @msg_ship_items;
    $msg_body->{shipments}[0]{shipment_items}   = bag(@msg_ship_items);

    # clear the AMQ queue and send again
    $test->{sender}->clear_destination( $test->{queue_name} );
    $test->{sender}->transform_and_send( 'XT::DC::Messaging::Producer::Order::VirtualVoucherCode', $shipment );
    $test->{sender}->assert_messages( {
        destination => $test->{queue_name},
        assert_header => superhashof({
            type => 'generate_virtual_voucher_code',
        }),
        assert_body => superhashof($msg_body),
    }, 'Request Virtual Voucher Code for only Virtual Items with no Code' );

}

Test::Class->runtests;
