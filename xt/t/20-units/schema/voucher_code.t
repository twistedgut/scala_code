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



my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

$schema->txn_do( sub {
    my $order       = _create_an_order();
    my $shipment    = $order->shipments->first;
    # only get voucher shipment items
    my @ship_items  = $shipment->shipment_items->search( { voucher_variant_id => { '!=' => undef } } )->all;

    # set-up data
    my $tmp;
    my $tmp_id;
    my @tmp;

    note "Assign Voucher Codes for Shipment Items";
    foreach my $item ( @ship_items ) {
        note "Item Id: ".$item->id;
        my $voucher = $item->voucher_variant->product;
        my $code    = $voucher->create_related( 'codes', { code => 'THISISATEST'.$voucher->id } );

        # assign and activate the code
        $item->update( { voucher_code_id => $code->id } );
        $code->assigned_code;

        $code->discard_changes;

        # check it's been assigned and activated correctly
        ok( defined $code->assigned, "Voucher Code: 'assigned' date has a value" );
        cmp_ok( $code->is_active, '==', 1, "Voucher Code: 'is_active' returns TRUE" );
        cmp_ok( $code->credit_logs->count(), '==', 1, "Voucher Code: only 1 credit log created" );
        $tmp    = $code->credit_logs->first;
        cmp_ok( $tmp->delta, '==', $voucher->value, "Voucher Credit Log: 'delta' is same as Voucher Value" );
        ok( !defined $tmp->spent_on_shipment_id, "Voucher Credit Log: 'spent_on_shipment_id' is null" );
    }

    note "Un-Assign Voucher Codes for Shipment Items";
    foreach my $item ( @ship_items ) {
        note "Item Id: ".$item->id;
        my $code    = $item->voucher_code;

        # unassign and deactivate voucher code
        $item->unassign_and_deactivate_voucher_code;

        $item->discard_changes;
        $code->discard_changes;

        # check it's been unassigned and deactivated correctly
        ok( !defined $item->voucher_code_id, "Shipment Item: 'voucher_code_id' is undefined" );
        ok( !defined $code->assigned, "Voucher Code: 'assigned' date is undefined" );
        ok( !$code->is_active, "Voucher Code: 'is_active' returns undef" );
        cmp_ok( $code->credit_logs->count(), '==', 0, "Voucher Code: there are 0 credit logs" );
    }

    note "Re Un-Assign Voucher Codes for Shipment Items to check when no codes assigned nothing DIES";
    foreach my $item ( @ship_items ) {
        note "Item Id: ".$item->id;

        # unassign and deactivate voucher code
        lives_ok( sub {
            $item->unassign_and_deactivate_voucher_code;
        }, "Un-Assigns Code when there is no Code OK" );
    }

    $schema->txn_rollback();
} );


done_testing();


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

