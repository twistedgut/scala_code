#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use lib '/opt/xt/deploy/xtracker/t/lib';

use Test::More;
use Test::XTracker::Data;
use XTracker::Constants::FromDB   qw(
            :channel
            :shipment_item_status
            :shipment_status
            :shipment_class
            :shipment_type
            :shipping_charge_class
            :renumeration_status
            :renumeration_class
            :renumeration_type
        );
use XTracker::Config::Local         qw( config_var sys_config_groups get_packing_station_printers dc_address );
use XTracker::Database::Currency    qw( get_currency_id );

my $schema = Test::XTracker::Data->get_schema();

our $channel_id = Test::XTracker::Data->get_local_channel_or_nap('nap')->id;

my $order = _create_an_order({
                    country    => "United Kingdom",
                    normal_pid => 1,
                    phys_vouch => 1,
                    virt_vouch => 1,
});

my $shipment = $order->shipments->first();

$shipment->print_sticker({
        printer => "Shipping Sticker 1",
        copies  => $shipment->shipment_items->count(),
});


# creates an order
sub _create_an_order {

    my $args    = shift;

    my $dc_name     = config_var('DistributionCentre','name');
    my $item_tax    = $args->{item_tax} || 50;
    my $item_duty   = $args->{item_duty} || 0;

    note "Creating Order";

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
        howmany => 1,
        phys_vouchers   => {
            how_many => 1,
            want_stock => 1,
            value => '150.00',
            assign_code_to_ship_item => 1,
        },
        virt_vouchers   => {
            how_many => 1,
            value => '250.00',
            assign_code_to_ship_item => 1,
        },
    });
    my @pids_to_use;
    push @pids_to_use, $pids->[0]       if ( $args->{normal_pid} );
    push @pids_to_use, $pids->[1]       if ( $args->{phys_vouch} );
    push @pids_to_use, $pids->[2]       if ( $args->{virt_vouch} );

    my $currency        = $args->{currency} || config_var('Currency', 'local_currency_code');

    my $currency_id     = get_currency_id( Test::XTracker::Data->get_schema->storage->dbh, $currency );
    my $carrier_name    = ( $dc_name eq "DC2" ? 'UPS' : config_var('DistributionCentre','default_carrier') );
    my $ship_account    = Test::XTracker::Data->find_shipping_account( { carrier => $carrier_name, channel_id => $channel->id } );
    my $prem_postcode   = Test::XTracker::Data->find_prem_postcode( $channel->id );
    my $postcode        = ( defined $prem_postcode ? $prem_postcode->postcode :
                            ( $dc_name eq "DC2" ? '11371' : 'NW10 4GR' ) );

    my $dc_address = dc_address($channel);

    my $address         = Test::XTracker::Data->order_address( {
                                                address         => 'create',
                                                address_line_1  => $dc_address->{addr1},
                                                address_line_2  => $dc_address->{addr2},
                                                address_line_3  => $dc_address->{addr3},
                                                towncity        => $dc_address->{city},
                                                county          => '',
                                                country         => $args->{country} || $dc_address->{country},
                                                postcode        => $postcode,
                                            } );

    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    my $base = {
        customer_id => $customer->id,
        currency_id => $currency_id,
        channel_id  => $channel->id,
        shipment_type => $SHIPMENT_TYPE__INTERNATIONAL,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id => $ship_account->id,
        invoice_address_id => $address->id,
        gift_shipment => ( exists( $args->{gift_shipment} ) ? $args->{gift_shipment} : 1 ),
    };


    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => \@pids_to_use,
        base => $base,
        attrs => [
            { price => 100.00, tax => $item_tax, duty => $item_duty },
        ],
    });

    $order->shipments->first->shipment_items->update( { tax => $item_tax } );

    return $order;
}

