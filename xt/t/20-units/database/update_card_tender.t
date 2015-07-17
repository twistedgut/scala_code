#!/usr/bin/env perl

use NAP::policy qw/test/;
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
use_ok( 'XTracker::Database::Invoice', qw( update_card_tender_value ) );
use_ok( 'XTracker::Order::Actions::ProcessPayment' );
can_ok( 'XTracker::Database::Order', qw( get_order_total_charge ) );
can_ok( 'XTracker::Database::Invoice', qw( update_card_tender_value ) );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

$schema->txn_do( sub {
    my $order       = _create_an_order();
    my $shipment    = $order->shipments->first;
    my $voucher     = Test::XTracker::Data->create_voucher();
    my $vouch_code  = $voucher->create_related( 'codes', { code => 'THISISATEST'.$voucher->id } );

    # set-up data
    my $tmp;
    my $tmp_id;
    my @tmp;
    my $tenders = $order->tenders;
    my $renums  = $shipment->renumerations;
    $tenders->delete;

    my $vcredit = $order->create_related( 'tenders', {
                                rank    => 2,
                                value   => 50,
                                voucher_code_id => $vouch_code->id,
                                type_id => $RENUMERATION_TYPE__VOUCHER_CREDIT,
                            } );
    my $debit   = $order->create_related( 'tenders', {
                                rank    => 1,
                                value   => 50,
                                type_id => $RENUMERATION_TYPE__CARD_DEBIT,
                            } );
    $tmp_id     = $debit->id;
    my $scredit = $order->create_related( 'tenders', {
                                rank    => 3,
                                value   => 55,
                                type_id => $RENUMERATION_TYPE__STORE_CREDIT,
                            } );

    note "Add/Subtract value for existing Card Debit tender";

    $tmp    = update_card_tender_value( $order, 25 );
    isa_ok( $tmp, 'XTracker::Schema::Result::Orders::Tender', "'update_card_tender_value' call Returned correct object" );
    $debit->discard_changes;
    $vcredit->discard_changes;
    $scredit->discard_changes;
    cmp_ok( $tmp->id, '==', $debit->id, "'update_card_tender_value' returned same rec as prievously created" );
    cmp_ok( $debit->value, '==', 75, "Add 25 increases Debit Value to be 75" );
    cmp_ok( $vcredit->value, '==', 50, "Voucher Credit un-changed" );
    cmp_ok( $scredit->value, '==', 55, "Store Credit un-changed" );

    $tmp    = update_card_tender_value( $order, -10 );
    isa_ok( $tmp, 'XTracker::Schema::Result::Orders::Tender', "'update_card_tender_value' call Returned correct object" );
    $debit->discard_changes;
    $vcredit->discard_changes;
    $scredit->discard_changes;
    cmp_ok( $tmp->id, '==', $debit->id, "'update_card_tender_value' returned same rec as prievously created" );
    cmp_ok( $debit->value, '==', 65, "Minus 10 decreases Debit Value to be 65" );
    cmp_ok( $vcredit->value, '==', 50, "Voucher Credit un-changed" );
    cmp_ok( $scredit->value, '==', 55, "Store Credit un-changed" );

    note "Delete the existing Card Debit tender";

    $debit->delete;
    $tmp    = update_card_tender_value( $order, -5 );
    ok( !defined $tmp, "'update_card_tender_value' with No Debit created and with a minus number returned undefined and didn't create anything" );
    cmp_ok( $tenders->count(), '==', 2, "Only 2 tenders created" );
    $vcredit->discard_changes;
    $scredit->discard_changes;
    cmp_ok( $vcredit->value, '==', 50, "Voucher Credit un-changed" );
    cmp_ok( $scredit->value, '==', 55, "Store Credit un-changed" );

    $tmp    = update_card_tender_value( $order, 34 );
    isa_ok( $tmp, 'XTracker::Schema::Result::Orders::Tender', "'update_card_tender_value' with No Debit and with a positve number returned correct object" );
    $vcredit->discard_changes;
    $scredit->discard_changes;
    cmp_ok( $tenders->count(), '==', 3, "Now 3 tenders created" );
    cmp_ok( $tmp->id, '>', $tmp_id, "new Debit tender Id is greater than deleted debit tender" );
    cmp_ok( $tmp->value, '==', 34, "new Debit tender has correct value" );
    cmp_ok( $tmp->rank, '==', 4, "new Debit tender has correct rank" );
    cmp_ok( $tmp->type_id, '==', $RENUMERATION_TYPE__CARD_DEBIT, "new Debit tender has correct renumeration type" );
    cmp_ok( $vcredit->value, '==', 50, "Voucher Credit un-changed" );
    cmp_ok( $scredit->value, '==', 55, "Store Credit un-changed" );

    note "Delete all existing Tenders and add a new Card Debit";
    $tmp_id = $tmp->id;
    $tmp->delete;
    $vcredit->delete;
    $scredit->delete;
    $tmp    = update_card_tender_value( $order, 27 );
    isa_ok( $tmp, 'XTracker::Schema::Result::Orders::Tender', "'update_card_tender_value' with No Tenders and with a positve number returned correct object" );
    cmp_ok( $tenders->count(), '==', 1, "Now with ony 1 tender created" );
    cmp_ok( $tmp->id, '>', $tmp_id, "new Debit tender Id is greater than deleted debit tender" );
    cmp_ok( $tmp->value, '==', 27, "new Debit tender has correct value" );
    cmp_ok( $tmp->rank, '==', 1, "new Debit tender has correct rank" );
    cmp_ok( $tmp->type_id, '==', $RENUMERATION_TYPE__CARD_DEBIT, "new Debit tender has correct renumeration type" );

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

