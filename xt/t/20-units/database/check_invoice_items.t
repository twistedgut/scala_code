#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use base 'Test::Class';

use Test::XTracker::Data;
use String::Random;

use XTracker::Config::Local     qw( config_var );
use XTracker::Constants         qw( :application );
use XTracker::Constants::FromDB qw(
                                    :shipment_status
                                    :shipment_item_status
                                    :order_status
                                    :renumeration_class
                                    :renumeration_status
                                    :renumeration_type
                                );
use XTracker::Database::Invoice qw( get_invoice_item_info );

sub create_order {
    my ( $self, $args ) = @_;
    my $pids_to_use = $args->{pids_to_use};
    my ($order) = Test::XTracker::Data->apply_db_order({
        pids => $self->{pids}{ $pids_to_use },
        attrs => [ { price => $args->{price} }, ],
        base => {
            tenders => $args->{tenders},
            shipment_status => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__PACKED,
        },
    });
    note "Order Nr/Id: ".$order->order_nr."/".$order->id;
    note "Shipment Id: ".$order->shipments->first->id;
    $order->shipments->first->renumerations->delete;

    return $order;
}

sub startup : Tests(startup) {
    my $test = shift;

    $test->{schema} = Test::XTracker::Data->get_schema;
    my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
        how_many => 1, channel => 'nap',
        phys_vouchers => {
            how_many => 1,
        },
        virt_vouchers => {
            how_many => 1,
        },
    });
    $pids->[2]{assign_code_to_ship_item}    = 1;
    $test->{pids}{virt_vouch_only}          = [ $pids->[2] ];
    $test->{pids}{phys_and_virt_vouchers}   = [ $pids->[1], $pids->[2] ];
    $test->{pids}{mixed}                    = $pids;

    $test->{op_id}  = $APPLICATION_OPERATOR_ID;
}

sub test_mixed_order : Tests {
    my $test = shift;
    my $order       = $test->create_order( { pids_to_use => 'mixed' } );

    my $shipment= $order->shipments->first;
    # get shipment items
    my @items   = $shipment->shipment_items->all;

    # create an invoice
    my $invoice = $shipment->create_related( 'renumerations', {
                                                invoice_nr              => '',
                                                renumeration_type_id    => $RENUMERATION_TYPE__CARD_DEBIT,
                                                renumeration_class_id   => $RENUMERATION_CLASS__ORDER,
                                                renumeration_status_id  => $RENUMERATION_STATUS__COMPLETED,
                                                shipping                => $shipment->shipping_charge,
                                                store_credit            => -310,
                                                currency_id             => $order->currency_id,
                                        } );
    foreach my $item ( @items ) {
        $item->create_related( 'renumeration_items', {
                                    renumeration_id => $invoice->id,
                                    unit_price      => $item->unit_price,
                                    tax             => $item->tax,
                                    duty            => $item->duty,
                                } );
    }
    my @renum_items = $invoice->renumeration_items->all;

    # call get invoice items and check
    # we get a row for every item
    my $inv_items   = get_invoice_item_info( $test->{schema}->storage->dbh, $invoice->id );

    cmp_ok( scalar( keys %{ $inv_items } ), '==', scalar( @items ), "Number of Invoice Items same as Shipment Items" );
    foreach my $item ( @renum_items ) {
        ok( exists($inv_items->{ $item->id }), "Invoice Item Id is in List: ".$item->id );
        my $tmp = $inv_items->{ $item->id };
        map { ok( exists( $tmp->{ $_ } ), "Key: $_ found for Item") } qw(
                                                                id
                                                                renumeration_id
                                                                shipment_item_id
                                                                unit_price
                                                                tax
                                                                duty
                                                                variant
                                                                size_id
                                                                legacy_sku
                                                                sku
                                                                product_id
                                                                size
                                                                designer
                                                                name
                                                        );
        if ( $item->shipment_item->voucher_variant_id ) {
            # for voucher items add a couple of extra tests
            ok( exists( $tmp->{voucher} ), "Key: voucher found for item" );
            ok( exists( $tmp->{is_physical} ), "Key: is_physical found for item" );
        }
    }
}

Test::Class->runtests;
