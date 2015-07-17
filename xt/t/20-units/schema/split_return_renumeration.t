#!/usr/bin/env perl
use NAP::policy qw/test/;

use Test::XTracker::Data;

use Data::Dump      qw( pp );

use XTracker::Constants           qw( :application );
use XTracker::Constants::FromDB   qw(
                                        :channel
                                        :currency
                                        :customer_issue_type
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                        :renumeration_status
                                        :renumeration_class
                                        :renumeration_type
                                        :return_status
                                        :return_item_status
                                    );

use XTracker::Config::Local         qw( config_var config_section_slurp dc_address );
use Test::XTracker::MessageQueue;
use XT::Domain::Returns;

use_ok( 'XTracker::Database::Invoice', qw( generate_invoice_number ) );

my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

ok(
    my $domain = XT::Domain::Returns->new(
        schema => $schema,
        msg_factory => Test::XTracker::MessageQueue->new({
            schema => $schema,
        }),
    ),
    "Created Returns domain"
);


$schema->txn_do( sub {
    my $order       = _create_an_order();
    my $shipment    = $order->shipments->first;
    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'id ASC' } )->all;

    my @tmp;
    my $tmp;

    my $return  = $domain->create({
            operator_id   => $APPLICATION_OPERATOR_ID,
            shipment_id   => $shipment->id,
            pickup => 0,
            refund_type_id => $RENUMERATION_TYPE__STORE_CREDIT,
            return_items    => {
                $ship_items[0]->id => {
                    type => 'Return',
                    reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                },
                $ship_items[1]->id => {
                    type => 'Return',
                    reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                },
                $ship_items[2]->id => {
                    type => 'Return',
                    reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                },
            }
        });
    $return->discard_changes;
    note "Return Id/RMA: ".$return->id."/".$return->rma_number;
    # get Renumeration for Return
    my $invoice = $return->renumerations->first;
    note "Return Invoice Id: ".$invoice->id.", Total Value: ".$invoice->grand_total;
    my $orig_inv_total  = $invoice->grand_total;

    note "Check Renumeration Tenders add up to Invoice Total before we start playing with the invoice";
    @tmp    = $invoice->renumeration_tenders;
    $tmp    = 0;
    foreach my $tender ( @tmp ) {
        $tmp    += $tender->value;
    }
    cmp_ok( $tmp, '==', $orig_inv_total, "Sum of Renumeration Tenders equal Invoice Total" );

    # update only some of the return items to be Passed QC
    # ready for the renumeration split
    my @ret_items   = $return->return_items->search( {}, { order_by => 'shipment_item_id' } )->all;
    $ret_items[0]->update( { return_item_status_id => $RETURN_ITEM_STATUS__PASSED_QC } );
    $ret_items[1]->update( { return_item_status_id => $RETURN_ITEM_STATUS__PASSED_QC } );

    # get the above completed records - just like in the real code
    note "Get a list of the QC Completed Return Items we've just set-up";
    my $return_item_rs  = $return->return_items->passed_qc;
    isa_ok( $return_item_rs, "XTracker::Schema::ResultSet::Public::ReturnItem", "Got a Completed Return Item result set" );

    note "Split the Invoice";
    my $new_inv_total   = $ship_items[0]->unit_price + $ship_items[1]->unit_price;
    $invoice->split_me( $return_item_rs );
    cmp_ok( $invoice->grand_total, '==', $orig_inv_total - $new_inv_total, "Old Invoice Grand Total now less the 2 Accepted Items: ". ( $orig_inv_total - $new_inv_total ) );
    my $new_invoice = $return->renumerations->search( {}, { order_by => 'renumeration.id DESC' } )->first;
    cmp_ok( $new_invoice->id, '>', $invoice->id, "New Invoice Id is greater than old Invoice Id: ".$new_invoice->id );
    cmp_ok( $new_invoice->grand_total, '==', $new_inv_total, "New Invoice Grand Total is equal to the 2 Accepted Items: ".$new_inv_total );

    note "For the Original Invoice: Renumeration Tenders should add up to the new Invoice Total: " . ( $orig_inv_total - $new_inv_total );
    @tmp    = $invoice->renumeration_tenders;
    $tmp    = 0;
    foreach my $tender ( @tmp ) {
        $tmp    += $tender->value;
    }
    cmp_ok( $tmp, '==', $orig_inv_total - $new_inv_total, "Sum of Renumeration Tenders equal new Invoice Total" );

    note "For the New Invoice: Renumeration Tenders should add up to the Invoice Total: " . $new_inv_total;
    @tmp    = $new_invoice->renumeration_tenders;
    $tmp    = 0;
    foreach my $tender ( @tmp ) {
        $tmp    += $tender->value;
    }
    cmp_ok( $tmp, '==', $new_inv_total, "Sum of Renumeration Tenders equal Invoice Total" );

    $schema->txn_rollback();
} );


done_testing();


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
            { price => 150.00,
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
    $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED } );

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
        $item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } );
        note "Shipment Item Id: ".$item->id.", Price: ".$item->unit_price.", Tax: ".$item->tax.", Duty: ".$item->duty;
    }

    $order->create_related( 'tenders', {
                                value   => sprintf( "%.2f", ($renum->grand_total / 2) ),
                                type_id => $RENUMERATION_TYPE__CARD_DEBIT,
                                rank    => 1,
                            } );
    $order->create_related( 'tenders', {
                                value   => sprintf( "%.2f", ($renum->grand_total / 2) ),
                                type_id => $RENUMERATION_TYPE__STORE_CREDIT,
                                rank    => 0,
                            } );

    note "Invoice Value: ".$renum->grand_total;

    return $order;
}

