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
use_ok( 'XTracker::Database::Invoice', qw( create_invoice create_renum_tenders_for_order_tenders ) );
use_ok( 'XTracker::Order::Actions::ProcessPayment' );
can_ok( 'XTracker::Database::Order', qw( get_order_total_charge ) );
can_ok( 'XTracker::Database::Invoice', qw( create_invoice create_renum_tenders_for_order_tenders ) );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

$schema->txn_do( sub {
    my $order       = _create_an_order();
    my $shipment    = $order->shipments->first;
    my $voucher     = Test::XTracker::Data->create_voucher();
    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'me.id' } )->all;
    my $vouch_code  = $voucher->create_related( 'codes', { code => 'THISISATEST'.$voucher->id } );

    # set-up data
    my $inv_id;
    my $invoice1;
    my $invoice2;
    my $tmp;
    my @tmp;
    my $tenders = $order->tenders;
    my $renums  = $shipment->renumerations;
    my @ord_tenders;
    my @renum_tenders;
    $tenders->delete;

    # create tenders
    $tmp    = $order->create_related( 'tenders', {
                                rank    => 2,
                                value   => 60,
                                voucher_code_id => $vouch_code->id,
                                type_id => $RENUMERATION_TYPE__VOUCHER_CREDIT,
                            } );
    push @ord_tenders, $tmp;
    $tmp    = $order->create_related( 'tenders', {
                                rank    => 1,
                                value   => 110,
                                type_id => $RENUMERATION_TYPE__CARD_DEBIT,
                            } );
    push @ord_tenders, $tmp;
    $tmp    = $order->create_related( 'tenders', {
                                rank    => 0,
                                value   => 90,
                                type_id => $RENUMERATION_TYPE__STORE_CREDIT,
                            } );
    push @ord_tenders, $tmp;

    # create one refund invoice for one item
    $inv_id     = create_invoice( $schema->storage->dbh, $shipment->id, '', $RENUMERATION_TYPE__CARD_REFUND, $RENUMERATION_CLASS__RETURN,
                                        $RENUMERATION_STATUS__PENDING, 10, 0, 0, 0, 0, $CURRENCY__GBP, 0 );
    $invoice1   = $schema->resultset('Public::Renumeration')->find( $inv_id );
    $invoice1->create_related( 'renumeration_items', {
                                        shipment_item_id    => $ship_items[0]->id,
                                        unit_price          => 100,
                                        tax                 => 0,
                                        duty                => 0,
                                } );
    # create second refund invoice for another item
    $inv_id     = create_invoice( $schema->storage->dbh, $shipment->id, '', $RENUMERATION_TYPE__CARD_REFUND, $RENUMERATION_CLASS__RETURN,
                                        $RENUMERATION_STATUS__PENDING, 0, 0, 0, 0, 0, $CURRENCY__GBP, 0 );
    $invoice2   = $schema->resultset('Public::Renumeration')->find( $inv_id );
    $invoice2->create_related( 'renumeration_items', {
                                        shipment_item_id    => $ship_items[1]->id,
                                        unit_price          => 150,
                                        tax                 => 0,
                                        duty                => 0,
                                } );

    note "Testing using 1st Invoice";
    # create renumeration tenders for specific order tenders, the total amount is 110 (100 + 10 for shipping)
    create_renum_tenders_for_order_tenders( $invoice1, [ $ord_tenders[2], $ord_tenders[1] ] );

    # check they were created properly for the right tenders, use last order tender first so sort occordingly
    @renum_tenders  = $invoice1->renumeration_tenders->search( {}, { order_by => 'tender_id DESC' } )->all;
    cmp_ok( @renum_tenders, '==', 2, "2 Renumeration Tenders were created" );
    cmp_ok( $renum_tenders[0]->tender_id, '==', $ord_tenders[2]->id, "1st Renum Tender is for the correct Order Tender" );
    cmp_ok( $renum_tenders[0]->value, '==', 90, "1st Renum Tender value is for value of 90" );
    cmp_ok( $renum_tenders[1]->tender_id, '==', $ord_tenders[1]->id, "2nd Renum Tender is for the correct Order Tender" );
    cmp_ok( $renum_tenders[1]->value, '==', 20, "2nd Renum Tender value is for value of 20" );

    note "Testing using 2nd Invoice";
    # create renumeration tenders for specific order tenders, the total amount is 150
    # ord_tenders[2] shouldn't be used as it's already been used up
    create_renum_tenders_for_order_tenders( $invoice2, [ $ord_tenders[2], $ord_tenders[1], $ord_tenders[0] ] );

    # check they were created properly for the right tenders, use last order tender first so sort occordingly
    @renum_tenders  = $invoice2->renumeration_tenders->search( {}, { order_by => 'tender_id DESC' } )->all;
    cmp_ok( @renum_tenders, '==', 2, "2 Renumeration Tenders were created" );
    cmp_ok( $renum_tenders[0]->tender_id, '==', $ord_tenders[1]->id, "1st Renum Tender is for the correct Order Tender" );
    cmp_ok( $renum_tenders[0]->value, '==', 90, "1st Renum Tender value is for value of 90" );
    cmp_ok( $renum_tenders[1]->tender_id, '==', $ord_tenders[0]->id, "2nd Renum Tender is for the correct Order Tender" );
    cmp_ok( $renum_tenders[1]->value, '==', 60, "2nd Renum Tender value is for value of 60" );

    note "Testing all order.tenders have remaining values as ZERO";
    foreach my $tender ( @ord_tenders ) {
        $tender->discard_changes;
        cmp_ok( $tender->remaining_value, '==', 0, "Order Tender: ".$tender->id." has ZERO remaining value" );
    }

    note "Test last renumeration tender is given more when orders.tender run out of value";
    # delete exising renum_tenders
    $invoice2->search_related('renumeration_tenders')->delete;
    # only pass in 2 out of the 3 tenders
    create_renum_tenders_for_order_tenders( $invoice2, [ $ord_tenders[2], $ord_tenders[1] ] );
    @renum_tenders  = $invoice2->renumeration_tenders->search( {}, { order_by => 'tender_id DESC' } )->all;
    cmp_ok( @renum_tenders, '==', 1, "1 Renumeration Tender was created" );
    cmp_ok( $renum_tenders[0]->tender_id, '==', $ord_tenders[1]->id, "1st Renum Tender is for the correct Order Tender" );
    cmp_ok( $renum_tenders[0]->value, '==', 150, "1st Renum Tender value is for value of 150" );

    note "Repeat again but use multiple tenders this time";
    # delete exising renum_tenders
    $invoice2->search_related('renumeration_tenders')->delete;
    # change the total value of the invoice from 150 to 170
    $invoice2->update( { shipping => 10 } );
    $invoice2->renumeration_items->first->update( { unit_price => 160 } );

    # ord_tenders[2] shouldn't be used as it's already been used up
    create_renum_tenders_for_order_tenders( $invoice2, [ $ord_tenders[2], $ord_tenders[1], $ord_tenders[0] ] );

    # check they were created properly for the right tenders, use last order tender first so sort occordingly
    @renum_tenders  = $invoice2->renumeration_tenders->search( {}, { order_by => 'tender_id DESC' } )->all;
    cmp_ok( @renum_tenders, '==', 2, "2 Renumeration Tenders were created" );
    cmp_ok( $renum_tenders[0]->tender_id, '==', $ord_tenders[1]->id, "1st Renum Tender is for the correct Order Tender" );
    cmp_ok( $renum_tenders[0]->value, '==', 90, "1st Renum Tender value is for value of 90" );
    cmp_ok( $renum_tenders[1]->tender_id, '==', $ord_tenders[0]->id, "2nd Renum Tender is for the correct Order Tender" );
    cmp_ok( $renum_tenders[1]->value, '==', 80, "2nd Renum Tender value is for value of 80" );

    $schema->txn_rollback();
} );


done_testing();


# create an order
sub _create_an_order {

    my $args    = shift;

    note "Creating Order";

    my($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 2,
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
            { price => 150.00 },
        ],
    });

    return $order;
}

