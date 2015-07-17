#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Carrier;

use Data::Dump      qw( pp );

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



use_ok( 'XTracker::Database::Invoice', qw( generate_invoice_number ) );
use_ok( 'XTracker::Order::Actions::ProcessPayment' );
use_ok( 'XTracker::Schema::Result::Public::ShipmentItem', qw( refund_invoice_total ) );
can_ok( 'XTracker::Schema::Result::Public::ShipmentItem', qw( refund_invoice_total ) );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

$schema->txn_do( sub {
    my $order       = _create_an_order();
    my $shipment    = $order->shipments->first;
    my @ship_items  = $shipment->shipment_items->all;

    my $tmp;
    my ( $price, $tax, $duty );
    my @invoices;

    note "Check Total Refund Value for items, should be zero";
    foreach my $item ( @ship_items ) {
        note "SID: ".$item->id;
        ( $price, $tax, $duty ) = $item->refund_invoice_total;
        cmp_ok( $price, '==', 0, "Refund Total for 'Unit Price' is ZERO" );
        cmp_ok( $tax, '==', 0, "Refund Total for 'Tax' is ZERO" );
        cmp_ok( $duty, '==', 0, "Refund Total for 'Duty' is ZERO" );
    }

    note "Create a Refund Invoice for a Shipment Item";
    push @invoices, _create_invoice( $schema, {
                                    shipment    => $shipment,
                                    ship_item   => $ship_items[0],
                                    unit_price  => 30,
                                    tax         => 5,
                                    duty        => 4,
                            } );
    note "Check Total Refund Value for items, should be some values now";
    ( $price, $tax, $duty ) = $ship_items[0]->refund_invoice_total;
    cmp_ok( $price, '==', 30, "Refund Total for 'Unit Price' should be 30" );
    cmp_ok( $tax, '==', 5, "Refund Total for 'Tax' should be 5" );
    cmp_ok( $duty, '==', 4, "Refund Total for 'Duty' should be 4" );

    note "Create a Refund Invoice for Unit Price only and check totals add up";
    push @invoices, _create_invoice( $schema, {
                                    shipment    => $shipment,
                                    ship_item   => $ship_items[0],
                                    unit_price  => 20,
                                    status_id   => $RENUMERATION_STATUS__COMPLETED,
                                    type_id     => $RENUMERATION_TYPE__STORE_CREDIT,
                            } );
    ( $price, $tax, $duty ) = $ship_items[0]->refund_invoice_total;
    cmp_ok( $price, '==', 50, "Unit Price Only Ivoice: Refund Total for 'Unit Price' should be 50" );
    cmp_ok( $tax, '==', 5, "Unit Price Only Ivoice: Refund Total for 'Tax' should still be 5" );
    cmp_ok( $duty, '==', 4, "Unit Price Only Ivoice: Refund Total for 'Duty' should still be 4" );

    note "Create a Refund Invoice for Tax only and check totals add up";
    push @invoices, _create_invoice( $schema, {
                                    shipment    => $shipment,
                                    ship_item   => $ship_items[0],
                                    tax         => 10,
                                    status_id   => $RENUMERATION_STATUS__PRINTED,
                                    type_id     => $RENUMERATION_TYPE__STORE_CREDIT,
                                    class_id    => $RENUMERATION_CLASS__CANCELLATION,
                            } );
    ( $price, $tax, $duty ) = $ship_items[0]->refund_invoice_total;
    cmp_ok( $price, '==', 50, "Tax Only Ivoice: Refund Total for 'Unit Price' should still be 50" );
    cmp_ok( $tax, '==', 15, "Tax Only Ivoice: Refund Total for 'Tax' should be 15" );
    cmp_ok( $duty, '==', 4, "Tax Only Ivoice: Refund Total for 'Duty' should still be 4" );

    note "Create a Refund Invoice for Duty only and check totals add up";
    push @invoices, _create_invoice( $schema, {
                                    shipment    => $shipment,
                                    ship_item   => $ship_items[0],
                                    duty        => 13,
                                    status_id   => $RENUMERATION_STATUS__AWAITING_AUTHORISATION,
                                    type_id     => $RENUMERATION_TYPE__STORE_CREDIT,
                            } );
    ( $price, $tax, $duty ) = $ship_items[0]->refund_invoice_total;
    cmp_ok( $price, '==', 50, "Duty Only Ivoice: Refund Total for 'Unit Price' should still be 50" );
    cmp_ok( $tax, '==', 15, "Duty Only Ivoice: Refund Total for 'Tax' should still be 15" );
    cmp_ok( $duty, '==', 17, "Duty Only Ivoice: Refund Total for 'Duty' should be 17" );

    note "Create a Gratuity Invoice for Price/Duty & Tax only and check totals add up";
    push @invoices, _create_invoice( $schema, {
                                    shipment    => $shipment,
                                    ship_item   => $ship_items[0],
                                    unit_price  => 35,
                                    tax         => 17,
                                    duty        => 2,
                                    status_id   => $RENUMERATION_STATUS__AWAITING_ACTION,
                                    class_id    => $RENUMERATION_CLASS__GRATUITY,
                            } );
    ( $price, $tax, $duty ) = $ship_items[0]->refund_invoice_total;
    cmp_ok( $price, '==', 85, "Gratuity Ivoice: Refund Total for 'Unit Price' should be 85" );
    cmp_ok( $tax, '==', 32, "Gratuity Ivoice: Refund Total for 'Tax' should be 32" );
    cmp_ok( $duty, '==', 19, "Gratuity Ivoice: Refund Total for 'Duty' should be 19" );

    note "Cancel the Original Invoice and Totals should be Reduced Appropriately";
    $invoices[0]->update( { renumeration_status_id => $RENUMERATION_STATUS__CANCELLED } );
    ( $price, $tax, $duty ) = $ship_items[0]->refund_invoice_total;
    cmp_ok( $price, '==', 55, "Cancelled Ivoice: Refund Total for 'Unit Price' should be 55" );
    cmp_ok( $tax, '==', 27, "Cancelled Ivoice: Refund Total for 'Tax' should be 27" );
    cmp_ok( $duty, '==', 15, "Cancelled Ivoice: Refund Total for 'Duty' should be 15" );

    note "Cancel all Invoices and Totals should be back to ZERO again";
    $_->update( { renumeration_status_id => $RENUMERATION_STATUS__CANCELLED } )     foreach ( @invoices );
    ( $price, $tax, $duty ) = $ship_items[0]->refund_invoice_total;
    cmp_ok( $price, '==', 0, "Cancelled all Invoices: Refund Total for 'Unit Price' is ZERO" );
    cmp_ok( $tax, '==', 0, "Cancelled all Invoices: Refund Total for 'Tax' is ZERO" );
    cmp_ok( $duty, '==', 0, "Cancelled all Invoices: Refund Total for 'Duty' is ZERO" );


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
            { price => 110.00,
              tax => 50,
              duty => 20 },
        ],
    });

    # clean up data created by the 'create order' test function
    $order->tenders->delete;
    my $shipment    = $order->shipments->first;
    $shipment->renumerations->delete;
    my @ship_items  = $shipment->shipment_items->all;

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

    return $order;
}

