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

use Test::Exception;


use_ok( 'XTracker::Database::Order', qw( get_order_total_charge get_order_info ) );
use_ok( 'XTracker::Database::Shipment', qw( get_order_shipment_info ) );
use_ok( 'XTracker::Database::Invoice', qw( create_renum_tenders_for_refund create_invoice generate_invoice_number adjust_existing_renum_tenders ) );
use_ok( 'XTracker::Order::Actions::ProcessPayment' );
can_ok( 'XTracker::Database::Order', qw( get_order_total_charge ) );
can_ok( 'XTracker::Database::Invoice', qw( create_renum_tenders_for_refund adjust_existing_renum_tenders ) );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

$schema->txn_do( sub {
    my $order       = _create_an_order();
    my $shipment    = $order->shipments->first;
    my $voucher     = Test::XTracker::Data->create_voucher();
    my $vouch_code  = $voucher->create_related( 'codes', { code => 'THISISATEST'.$voucher->id } );

    # set-up data
    my $tmp;
    my @tmp;
    my $tenders = $order->tenders;
    my $renums  = $shipment->renumerations;
    $tenders->delete;

    my $inv_id  = create_invoice( $schema->storage->dbh, $shipment->id, '1', $RENUMERATION_TYPE__CARD_DEBIT, $RENUMERATION_CLASS__ORDER,
                                    $RENUMERATION_STATUS__COMPLETED, 10, 0, 0, 1, 2, $CURRENCY__GBP, 50 );
    my $invoice = $schema->resultset('Public::Renumeration')->find( $inv_id );

    $order->create_related( 'tenders', {
                                rank    => 2,
                                value   => 50,
                                voucher_code_id => $vouch_code->id,
                                type_id => $RENUMERATION_TYPE__VOUCHER_CREDIT,
                            } );
    create_renum_tenders_for_refund( $order, $invoice, 45 );
    cmp_ok( $invoice->renumeration_tenders->count, '==', 1, "1 renum tender created" );
    cmp_ok( $invoice->renumeration_tenders->first->value, '==', 45, "renum tender value is correct" );

    note "Increase previous invoice value to 65";
    adjust_existing_renum_tenders( $invoice, 65 );
    cmp_ok( $invoice->renumeration_tenders->count, '==', 1, "1 renum tender created" );
    cmp_ok( $invoice->renumeration_tenders->first->value, '==', 65, "renum tender value is correct" );

    note "Decrease previous invoice value back to 45";
    adjust_existing_renum_tenders( $invoice, 45 );
    cmp_ok( $invoice->renumeration_tenders->count, '==', 1, "1 renum tender created" );
    cmp_ok( $invoice->renumeration_tenders->first->value, '==', 45, "renum tender value is correct" );

    # new invoice
    $inv_id = create_invoice( $schema->storage->dbh, $shipment->id, '2', $RENUMERATION_TYPE__CARD_DEBIT, $RENUMERATION_CLASS__ORDER,
                                    $RENUMERATION_STATUS__COMPLETED, 10, 0, 0, 1, 2, $CURRENCY__GBP, 50 );
    $invoice= $schema->resultset('Public::Renumeration')->find( $inv_id );

    $order->create_related( 'tenders', {
                                rank    => 1,
                                value   => 50,
                                type_id => $RENUMERATION_TYPE__CARD_DEBIT,
                            } );
    my $tender  = $order->create_related( 'tenders', {
                                rank    => 0,
                                value   => 55,
                                type_id => $RENUMERATION_TYPE__STORE_CREDIT,
                            } );
    create_renum_tenders_for_refund( $order, $invoice, 55 );
    @tmp    = $invoice->renumeration_tenders->search( {}, { join => 'tender', order_by => 'tender.rank DESC' } )->all;
    cmp_ok( @tmp, '==', 2, "2 renum tenders created" );
    cmp_ok( $tmp[0]->value, '==', 5, "first renum tender value is 5" );
    cmp_ok( $tmp[1]->value, '==', 50, "second renum tender value is 50" );
    cmp_ok( $tender->renumeration_tenders->count, '==', 0, "Didn't use Store Credit tender" );

    note "Reduce the previous amount by 5";
    adjust_existing_renum_tenders( $invoice, 50 );
    @tmp    = $invoice->renumeration_tenders->search( {}, { join => 'tender', order_by => 'tender.rank DESC' } )->all;
    cmp_ok( @tmp, '==', 2, "2 renum tenders created" );
    cmp_ok( $tmp[0]->value, '==', 5, "first renum tender value is 5" );
    cmp_ok( $tmp[1]->value, '==', 45, "second renum tender value is 45" );
    cmp_ok( $tender->renumeration_tenders->count, '==', 0, "Didn't use Store Credit tender" );

    # new invoice
    $inv_id = create_invoice( $schema->storage->dbh, $shipment->id, '3', $RENUMERATION_TYPE__CARD_DEBIT, $RENUMERATION_CLASS__ORDER,
                                    $RENUMERATION_STATUS__COMPLETED, 10, 0, 0, 1, 2, $CURRENCY__GBP, 150 );
    $invoice= $schema->resultset('Public::Renumeration')->find( $inv_id );
    dies_ok( sub {
        create_renum_tenders_for_refund( $order, $invoice, 105 );
    }, "Not enough Tenders to honour Refund Amount" );

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

