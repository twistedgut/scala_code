#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Carrier;

use XTracker::Constants::FromDB   qw(
                                        :channel
                                        :currency
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                        :renumeration_status
                                        :renumeration_class
                                        :renumeration_type
                                    );

use XTracker::Config::Local             qw( config_var dc_address );



use_ok( 'XTracker::Database::Order', qw( get_order_total_charge get_order_info ) );
use_ok( 'XTracker::Database::Shipment', qw( get_order_shipment_info ) );
use_ok( 'XTracker::Database::Invoice', qw( create_invoice generate_invoice_number ) );
use_ok( 'XTracker::Database::OrderPayment' );
can_ok( 'XTracker::Database::Order', qw( get_order_total_charge ) );
can_ok( 'XTracker::Database::Invoice', qw( create_invoice ) );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

$schema->txn_do( sub {
    my $order       = _create_an_order();
    my $shipment    = $order->shipments->first;
    my $voucher     = Test::XTracker::Data->create_voucher();
    my $vouch_code  = $voucher->create_related( 'codes', { code => 'THISISATEST'.$voucher->id } );

    # set-up data
    my $tmp;
    my $tenders = $order->tenders;
    my $renums  = $shipment->renumerations;
    $tenders->delete;
    $renums->delete;
    my $invoice_number = generate_invoice_number( $schema->storage->dbh );
    $tmp    = create_invoice( $schema->storage->dbh, $shipment->id, $invoice_number, $RENUMERATION_TYPE__CARD_DEBIT, $RENUMERATION_CLASS__ORDER,
                                $RENUMERATION_STATUS__COMPLETED, 10, 0, 0, 1, 2, $CURRENCY__GBP );
    $tmp    = $schema->resultset('Public::Renumeration')->find( $tmp );
    isa_ok( $tmp, 'XTracker::Schema::Result::Public::Renumeration', "Created an Invoice without Gift Voucher Value Passed" );
    cmp_ok( $tmp->gift_voucher, '==', 0, "Gift Voucher value is zero" );
    cmp_ok( $tmp->sent_to_psp, '==', 0, "Sent to PSP is FALSE" );
    $tmp->delete;
    $tmp    = create_invoice( $schema->storage->dbh, $shipment->id, $invoice_number, $RENUMERATION_TYPE__CARD_DEBIT, $RENUMERATION_CLASS__ORDER,
                                $RENUMERATION_STATUS__COMPLETED, 10, 0, 0, 1, 2, $CURRENCY__GBP, 50 );
    $tmp    = $schema->resultset('Public::Renumeration')->find( $tmp );
    isa_ok( $tmp, 'XTracker::Schema::Result::Public::Renumeration', "Created an Invoice with Gift Voucher Value Passed" );
    cmp_ok( $tmp->gift_voucher, '==', 50, "Gift Voucher value shows up" );
    cmp_ok( $tmp->sent_to_psp, '==', 0, "Sent to PSP is FALSE" );
    $tmp->delete;

    $shipment->update( { shipping_charge => 10, store_credit => 0 } );
    $tmp = get_order_total_charge( $schema->storage->dbh, $order->id );
    cmp_ok( $tmp, '==', 110, "Basic Total Charge as expected" );
    $shipment->update( { store_credit => -5 } );
    $tmp    = get_order_total_charge( $schema->storage->dbh, $order->id );
    cmp_ok( $tmp, '==', 105, "Total Charge less Store Credit as expected" );
    $order->create_related( 'tenders', {
                                rank    => 1,
                                value   => 50,
                                voucher_code_id => $vouch_code->id,
                                type_id => $RENUMERATION_TYPE__VOUCHER_CREDIT,
                            } );
    $tmp    = get_order_total_charge( $schema->storage->dbh, $order->id );
    cmp_ok( $tmp, '==', 55, "Total Charge less Gift Voucher as expected" );

    my $order_info      = get_order_info( $schema->storage->dbh, $order->id );
    my $shipment_info   = get_order_shipment_info( $schema->storage->dbh, $order->id );

    XTracker::Database::OrderPayment::_create_invoice(
        $schema,
        $shipment->id,
        $shipment_info,
        $order_info
    );
    my $renum   = $shipment->renumerations->first;
    cmp_ok( $renum->gift_voucher, '==', -50, "Renumeration has Gift Voucher value on it" );

    $schema->txn_rollback();
} );


done_testing();


# create an order
sub _create_an_order {

    my $args    = shift;

    note "Creating Order";

    my($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 1,
    });

    my $ship_account    = Test::XTracker::Data->find_shipping_account( { carrier => config_var('DistributionCentre','default_carrier'), channel_id => $channel->id } );
    my $prem_postcode   = Test::XTracker::Data->find_prem_postcode( $channel->id );
    my $postcode        = ( defined $prem_postcode ? $prem_postcode->postcode :
                            ( $channel->is_on_dc( 'DC2' ) ? '11371' : 'NW10 4GR' ) );

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

#    my $pids        = Test::XTracker::Data->find_products( { channel_id => $channel->id } );
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

    return $order;
}

