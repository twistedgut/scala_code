#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Carrier;
use Test::XTracker::ParamCheck;
use Test::XTracker::Mock::PSP;

use XTracker::Constants           qw( :application );
use XTracker::Constants::FromDB   qw(
                                        :channel
                                        :customer_issue_type
                                        :currency
                                        :order_status
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                    );

use XTracker::Config::Local             qw( config_var dc_address );


use Test::Exception;
use DateTime;
use Data::Dump  qw( pp );

use_ok( 'XTracker::Database::Shipment', qw( get_cancel_putaway_list ) );
can_ok( 'XTracker::Database::Shipment', qw( get_cancel_putaway_list ) );

my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );
my $dbh = $schema->storage->dbh;

my $list;
my $tmp;
my @item_chk_keys;

$schema->txn_do( sub {
    my $order       = _create_an_order();
    my $shipment    = $order->shipments->first;
    my @items       = $shipment->shipment_items->all;
    my $ch_name     = $order->channel->name;
    my @cancel_items;

    note "Order Nr/Id: ".$order->order_nr."/".$order->id;
    note "Shipment Id: ".$shipment->id;

    # cancel the order
    $order->update( { order_status_id => $ORDER_STATUS__CANCELLED } );
    $order->create_related( 'order_status_logs', {
                                    order_status_id => $ORDER_STATUS__CANCELLED,
                                    operator_id     => $APPLICATION_OPERATOR_ID,
                                    date            => DateTime->now(),
                                } );
    # cancel the shipment
    $shipment->update_status( $SHIPMENT_STATUS__CANCELLED, $APPLICATION_OPERATOR_ID );

    note "Testing 'get_cancel_putaway_list'";
    # set the items to be CANCELLED PENDING
    foreach my $item ( @items ) {
        my $item_status = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING;

        if ( $item->is_virtual_voucher ) {
            # virtual voucher should always be CANCELLED
            $item_status    = $SHIPMENT_ITEM_STATUS__CANCELLED;
        }

        $item->update_status( $item_status, $APPLICATION_OPERATOR_ID );
        my $cancel_item = $item->create_related('cancelled_item', {
            customer_issue_type_id  => $CUSTOMER_ISSUE_TYPE__8__OTHER,
        });
        push @cancel_items, $cancel_item;
    }

    note "getting 'get_cancel_putaway_list'";

    @item_chk_keys  = qw(
                    id
                    legacy_sku
                    product_id
                    sku_size
                    description
                );

    $list   = get_cancel_putaway_list( $dbh );
    isa_ok( $list, 'HASH', "'get_cancel_putaway_list' returned" );
    ok( exists( $list->{ $ch_name } ), "Found correct Sales Channel in list: $ch_name" );

    $tmp    = $list->{ $ch_name };
    ok( exists( $tmp->{ $shipment->id } ), "Found Shipment Id in list" );
    ok( exists( $tmp->{ $shipment->id }{items} ), "Found 'items' for Shipment Id in list" );

    # check the items
    $tmp    = $tmp->{ $shipment->id }{items};
    foreach my $item ( @items ) {
        if ( $item->voucher_variant_id ) {
            ok( !exists( $tmp->{ $item->id } ), "Didn't Find Shipment Item Id for Virtual Voucher" )    if ( $item->is_virtual_voucher );
            ok( exists( $tmp->{ $item->id } ), "Found Shipment Item Id for Physical Voucher" )          if ( !$item->is_virtual_voucher );
        }
        else {
            ok( exists( $tmp->{ $item->id } ), "Found Shipment Item Id for Normal Product" );
        }
        if ( !$item->is_virtual_voucher ) {
            # check the expected keys exists
            map { ok( exists( $tmp->{ $item->id }{$_} ), "Key Exists: $_" ) } @item_chk_keys;

            # change the Item Status for the next test
            $item->update_status( $SHIPMENT_ITEM_STATUS__CANCELLED, $APPLICATION_OPERATOR_ID );
        }
    }
    $schema->txn_rollback();
} );


done_testing();

#--------------------------------------------------------------------------------------------------------

# create an order
sub _create_an_order {

    my $args    = shift;

    note "Creating Order";

    my($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 1,
        phys_vouchers => {
            how_many => 1,
            want_stock => 1,
        },
        virt_vouchers => {
            how_many => 1,
        },
    });
    $pids->[2]{assign_code_to_ship_item}    = 1;

    my $ship_account    = Test::XTracker::Data->find_shipping_account( { carrier => config_var('DistributionCentre','default_carrier'), channel_id => $channel->id } );
    my $prem_postcode   = Test::XTracker::Data->find_prem_postcode( $channel->id );
    my $postcode        = ( defined $prem_postcode ? $prem_postcode->postcode :
                            ( $channel->is_on_dc( 'DC2' ) ? '11371' : 'NW10 4GR' ) );

    my $dc_address      = dc_address($channel);
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
        channel_id  => $channel->id,
        shipment_type => $SHIPMENT_TYPE__DOMESTIC,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id => $ship_account->id,
        invoice_address_id => $address->id,
    };

    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => $base,
        attrs => [
            { price => 100.00 },
        ],
    });

    my @items   = $order->shipments->first->shipment_items->all;
    foreach my $item ( @items ) {
        $item->create_related( 'shipment_item_status_logs', {
                                        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                                        operator_id => $APPLICATION_OPERATOR_ID,
                                } );
        if ( $item->is_virtual_voucher ) {
            $item->create_related( 'shipment_item_status_logs', {
                                            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED,
                                            operator_id => $APPLICATION_OPERATOR_ID,
                                    } );
            $item->create_related( 'shipment_item_status_logs', {
                                            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
                                            operator_id => $APPLICATION_OPERATOR_ID,
                                    } );
            $item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED } );
        }
    }

    return $order;
}
