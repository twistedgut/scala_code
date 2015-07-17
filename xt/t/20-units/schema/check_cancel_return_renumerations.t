#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Carrier;

use Data::Dump      qw( pp );

use XTracker::Constants           qw( :application );
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
                                        :return_status
                                    );

use XTracker::Config::Local             qw( config_var dc_address );
use XTracker::Database::Return          qw( generate_RMA );


use Test::Exception;

use_ok( 'XTracker::Database::Invoice', qw( generate_invoice_number ) );
use_ok( 'XTracker::Order::Actions::ProcessPayment' );
use_ok( 'XTracker::Schema::Result::Public::ShipmentItem', qw( refund_invoice_total ) );
can_ok( 'XTracker::Schema::Result::Public::ShipmentItem', qw( refund_invoice_total ) );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

$schema->txn_do( sub {
    my $order       = _create_an_order();
    my $shipment    = $order->shipments->first;
    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'id ASC' } )->all;

    my $rs;
    my $tmp;
    my ( $price, $tax, $duty );
    my @invoices;
    my @returns;

    note "Test a Non-Refund Renumeration can't be Cancelled";
    $rs = $shipment->renumerations->search( { renumeration_class_id => $RENUMERATION_CLASS__ORDER } );
    lives_ok( sub {
        $rs->cancel_for_returns( $APPLICATION_OPERATOR_ID );
    }, "Cancel Non-Return Completed Orders" );
    $tmp    = $rs->first;
    cmp_ok( $tmp->renumeration_status_id, '!=', $RENUMERATION_STATUS__CANCELLED, "Non-Return Renumeration: ".$tmp->id.", is NOT Cancelled" );

    # Create some Refund Invoices for future_tests and set them to be completed
    my @refund_types    = ( $RENUMERATION_TYPE__CARD_REFUND, $RENUMERATION_TYPE__CARD_REFUND, $RENUMERATION_TYPE__STORE_CREDIT );
    foreach my $item ( @ship_items ) {
        $tmp    = _create_invoice( $schema, {
                                        shipment    => $shipment,
                                        ship_item   => $item,
                                        type_id     => shift @refund_types,
                                        unit_price  => $item->unit_price,
                                        tax         => 0,
                                        duty        => 0,
                                        status_id   => $RENUMERATION_STATUS__COMPLETED,
                                } );
        $tmp->create_related( 'renumeration_tenders', {
                                    tender_id   => $order->tenders->first->id,
                                    value       => $item->unit_price,
                                } );
        push @invoices, $tmp;
    }

    note "Testing Cancelling a lot of Renumerations with one Non-Refund one in there";
    lives_ok( sub {
        $shipment->renumerations->cancel_for_returns( $APPLICATION_OPERATOR_ID );
    }, "Cancelling a list of Renumerations with 1 Non-Refund in there" );
    foreach my $inv ( $shipment->renumerations->all ) {
        $inv->discard_changes;
        cmp_ok( $inv->renumeration_status_id, '!=', $RENUMERATION_STATUS__CANCELLED, "Renumeration: ".$inv->id.", is NOT Cancelled" );
    }

    # create Returns for the Renumerations
    # for 1 renumeration
    push @returns, $shipment->create_related( 'returns', {
                                    rma_number      => generate_RMA( $schema->storage->dbh, $shipment->id ),
                                    return_status_id=> $RETURN_STATUS__AWAITING_RETURN,
                                } );
    $returns[0]->create_related( 'link_return_renumerations', { renumeration_id => $invoices[0]->id } );
    # for the remaining 2 renumerations
    push @returns, $shipment->create_related( 'returns', {
                                    rma_number      => generate_RMA( $schema->storage->dbh, $shipment->id ),
                                    return_status_id=> $RETURN_STATUS__AWAITING_RETURN,
                                } );
    $returns[1]->create_related( 'link_return_renumerations', { renumeration_id => $invoices[1]->id } );
    $returns[1]->create_related( 'link_return_renumerations', { renumeration_id => $invoices[2]->id } );

    note "Test Cancelling 1 Renumeration that is Completed";
    dies_ok( sub {
        $returns[0]->renumerations->cancel_for_returns( $APPLICATION_OPERATOR_ID );
    }, "Cancel 1 Renumeration that is Complete should die" );
    like( $@, qr/Can't Cancel already Completed Invoices/, "Got 'can't cancel message'" );
    foreach my $inv ( $invoices[0] ) {
        $inv->discard_changes;
        cmp_ok( $inv->renumeration_status_id, '!=', $RENUMERATION_STATUS__CANCELLED, "Renumeration: ".$inv->id.", is NOT Cancelled" );
        cmp_ok( $inv->renumeration_tenders->count(), '>', 0, "Renumeration Tenders for Renumeration have NOT been Deleted" );
    }

    note "Test Cancelling 1 Renumeration that is not yet Complete";
    $returns[0]->renumerations->update( { renumeration_status_id => $RENUMERATION_STATUS__AWAITING_ACTION } );
    $returns[0]->renumerations->cancel_for_returns( $APPLICATION_OPERATOR_ID );
    foreach my $inv ( $invoices[0] ) {
        $inv->discard_changes;
        cmp_ok( $inv->renumeration_status_id, '==', $RENUMERATION_STATUS__CANCELLED, "Renumeration: ".$inv->id.", IS Cancelled" );
        cmp_ok( $inv->renumeration_tenders->count(), '==', 0, "Renumeration Tenders for Renumeration have been Deleted" );
    }

    note "Testing Cancelling 2 Renumerations that are Completed";
    dies_ok( sub {
        $returns[1]->renumerations->cancel_for_returns( $APPLICATION_OPERATOR_ID );
    }, "Cancel 2 Renumeration that are Completed should die" );
    like( $@, qr/Can't Cancel already Completed Invoices/, "Got 'can't cancel message'" );
    foreach my $inv ( $invoices[1], $invoices[2] ) {
        $inv->discard_changes;
        cmp_ok( $inv->renumeration_status_id, '!=', $RENUMERATION_STATUS__CANCELLED, "Renumeration: ".$inv->id.", is NOT Cancelled" );
        cmp_ok( $inv->renumeration_tenders->count(), '>', 0, "Renumeration Tenders for Renumeration have NOT been Deleted" );
    }

    note "Testing Cancelling 2 Renumerations when only 1 is Completed";
    $invoices[1]->update( { renumeration_status_id => $RENUMERATION_STATUS__AWAITING_ACTION } );
    $invoices[2]->update( { renumeration_status_id => $RENUMERATION_STATUS__COMPLETED } );
    dies_ok( sub {
        $returns[1]->renumerations->cancel_for_returns( $APPLICATION_OPERATOR_ID );
    }, "Cancel 2 Renumeration where only 1 is Complete should die" );
    like( $@, qr/Can't Cancel already Completed Invoices/, "Got 'can't cancel message'" );
    foreach my $inv ( $invoices[1], $invoices[2] ) {
        $inv->discard_changes;
        cmp_ok( $inv->renumeration_status_id, '!=', $RENUMERATION_STATUS__CANCELLED, "Renumeration: ".$inv->id.", is NOT Cancelled" );
        cmp_ok( $inv->renumeration_tenders->count(), '>', 0, "Renumeration Tenders for Renumeration have NOT been Deleted" );
    }

    note "Test Cancelling 2 Renumerations when neither is Complete yet";
    $invoices[1]->update( { renumeration_status_id => $RENUMERATION_STATUS__AWAITING_ACTION } );
    $invoices[2]->update( { renumeration_status_id => $RENUMERATION_STATUS__AWAITING_ACTION } );
    lives_ok( sub {
        $returns[1]->renumerations->cancel_for_returns( $APPLICATION_OPERATOR_ID );
    }, "Cancel 2 Renumeration where both are not Complete should be ok" );
    foreach my $inv ( $invoices[1], $invoices[2] ) {
        $inv->discard_changes;
        cmp_ok( $inv->renumeration_status_id, '==', $RENUMERATION_STATUS__CANCELLED, "Renumeration: ".$inv->id.", IS Cancelled" );
        cmp_ok( $inv->renumeration_tenders->count(), '==', 0, "Renumeration Tenders for Renumeration have been Deleted" );
    }

    $schema->txn_rollback();
} );


done_testing();


# create an invoice
sub _create_invoice {
    my ( $schema, $args )   = @_;

    my $renum   = $args->{shipment}->create_related( 'renumerations', {
                                        invoice_nr              => '',
                                        renumeration_type_id    => $args->{type_id} || $RENUMERATION_TYPE__CARD_REFUND,
                                        renumeration_class_id   => $args->{class_id} || $RENUMERATION_CLASS__RETURN,
                                        renumeration_status_id  => $args->{status_id} || $RENUMERATION_STATUS__PENDING,
                                        currency_id => ( Test::XTracker::Data->whatami eq 'DC2' ? $CURRENCY__USD : $CURRENCY__GBP ),
                                        sent_to_psp => 0,
                                } );
    $renum->create_related( 'renumeration_items', {
                                        shipment_item_id    => $args->{ship_item}->id,
                                        unit_price          => $args->{unit_price} || 0,
                                        tax                 => $args->{tax} || 0,
                                        duty                => $args->{duty} || 0,
                                } );

    return $renum;
}

# create an order
sub _create_an_order {

    my $args    = shift;

    note "Creating Order";

    my($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 3,
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
            { price => 100.00,
              tax => 0,
              duty => 0 },
            { price => 200.00,
              tax => 0,
              duty => 0 },
            { price => 300.00,
              tax => 0,
              duty => 0 },
        ],
    });

    # clean up data created by the 'create order' test function
    $order->tenders->delete;
    my $shipment    = $order->shipments->first;
    $shipment->renumerations->delete;
    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'id ASC' } )->all;

    note "Order Id/Nr: ".$order->id." / ".$order->order_nr;
    note "Shipment Id: ".$shipment->id;

    # create an initial DEBIT invoice
    my $invoice_number = generate_invoice_number( $schema->storage->dbh );
    my $renum   = $shipment->create_related( 'renumerations', {
                                invoice_nr              => $invoice_number,
                                renumeration_type_id    => $RENUMERATION_TYPE__CARD_DEBIT,
                                renumeration_class_id   => $RENUMERATION_CLASS__ORDER,
                                renumeration_status_id  => $RENUMERATION_STATUS__COMPLETED,
                                shipping    => 10,
                                currency_id => ( Test::XTracker::Data->whatami eq 'DC2' ? $CURRENCY__USD : $CURRENCY__GBP ),
                                sent_to_psp => 1,
                                gift_credit => 0,
                                misc_refund => 0,
                                store_credit=> 0,
                                gift_voucher=> 0,
                        } );
    foreach my $item ( @ship_items ) {
        $renum->create_related( 'renumeration_items', {
                                shipment_item_id    => $item->id,
                                unit_price          => $item->unit_price,
                                tax                 => $item->tax,
                                duty                => $item->duty,
                            } );
        note "Shipment Item Id: ".$item->id.", Price: ".$item->unit_price.", Tax: ".$item->tax.", Duty: ".$item->duty;
    }

    $order->create_related( 'tenders', {
                                value   => $renum->grand_total,
                                type_id => $RENUMERATION_TYPE__CARD_DEBIT,
                                rank    => 0,
                            } );

    return $order;
}

