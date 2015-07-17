#!/usr/bin/env perl
use NAP::policy "tt", "test";

=head1 NAME

shipment.t - for XTracker::Database::Shipment functions

=head1 DESCRIPTION

Tests various functionality in the 'XTracker::Database::Shipment' module.

=cut

use FindBin::libs;
use Test::XTracker::RunCondition ( export => '$distribution_centre' );
my $dc = $distribution_centre;

use XTracker::Database qw( :common );
use XTracker::Database::Shipment qw(
    update_shipment_shipping_charge_id
    update_shipment_status
    get_shipment_item_info
    create_shipment_hold
);

use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw (
    :shipment_status
    :shipment_hold_reason
);

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local qw( config_var );

my ($schema, $dbh) = get_schema_and_ro_dbh("xtracker_schema");

eval {
    verify_shipment_item_product_name_attribute_encoding();
    test_update_shipment_shipping_charge_id();
    test_broadcast_stock_levels();
    update_status_remove_hold_invalid_chars();
    check_create_shipment_hold();
    1;
} or fail( "Died: $@");

done_testing();


=head1 METHODS

=cut

sub test_update_shipment_shipping_charge_id {

    my $shipment = create_shipment();

    SKIP: {
        skip q{channel doesn't support premier shipments}, 5
            unless $shipment->get_channel->has_customer_facing_premier_shipping_charges;

        my $old_shipping_charge_id = $shipment->shipping_charge_id;
        note("Created shipment_id (" . $shipment->id . ")");

        is(
            $shipment->premier_routing->code,
            "C",
            "Default premier_routing is C, even though it's not a premier Shipping Charge"
        );

        my $premier_shipping_charge_sku = Test::Config->value( 'Premier' => 'shipping_charge_sku' );
        my $shipping_charge_id = id_from_sku($premier_shipping_charge_sku);
        note("Setting shipping_charge_id to ($shipping_charge_id)");
        update_shipment_shipping_charge_id(
            $dbh,
            $shipment->id,
            $shipping_charge_id,
        );
        $shipment->discard_changes();
        is(
            $shipment->shipping_charge_id,
            $shipping_charge_id,
            "shipping_charge_id updated",
        );
        is(
            $shipment->premier_routing->code,
            "D",
            "premier_routing got updated along with the shipping_charge",
        );

        my $non_premier_shipping_charge_sku = Test::Config->value( 'NonPremier' => 'shipping_charge_sku' );
        $shipping_charge_id = id_from_sku($non_premier_shipping_charge_sku);
        note("Setting shipping_charge_id to ($shipping_charge_id)");
        update_shipment_shipping_charge_id(
            $dbh,
            $shipment->id,
            $shipping_charge_id,
        );
        $shipment->discard_changes();
        is(
            $shipment->shipping_charge_id,
            $shipping_charge_id,
            "shipping_charge_id updated",
        );
        is(
            $shipment->premier_routing->code,
            "C",
            "premier_routing got updated along with the shipping_charge",
        );
    }

}

sub test_broadcast_stock_levels {
    my $amq = Test::XTracker::MessageQueue->new();
    my $destination = config_var('Producer::Stock::DetailedLevelChange', 'destination');

    # Let's not get confused by previous messages
    $amq->clear_destination($destination);

    # Shipment with one product, should broadcast one stock level message
    my $product_shipment = create_shipment();

    ok($product_shipment->broadcast_stock_levels, 'Broadcast stock levels does not die');

    $amq->assert_messages({
        destination => $destination,
        assert_count => 1,
    }, "Correct (1) stock messages sent for shipment");

    $amq->clear_destination($destination);

    # Shipment with one voucher, should broadcast one stock level message
    my (undef, $pids) = Test::XTracker::Data->grab_products({
            channel => Test::XTracker::Data->channel_for_nap(),
            phys_vouchers => {
                how_many => 1,
            },
    });
    shift @$pids; # remove the first product

    my $voucher_shipment = Test::XTracker::Data->create_domestic_order(
        channel => Test::XTracker::Data->channel_for_nap(),
        pids    => $pids, # We only want the voucher
    )->shipments->first;

    ok($voucher_shipment->broadcast_stock_levels, 'Broadcast stock levels does not die');

    $amq->assert_messages({
        destination => $destination,
        assert_count => 1,
    }, "Correct (1) stock messages sent for shipment");

    $amq->clear_destination($destination);

    # Shipment with one voucher and one product, should broadcast two messages
    my $voucher_product_shipment = create_shipment({ virt_vouchers => 1 });

    ok($voucher_product_shipment->broadcast_stock_levels,
        'Broadcast stock levels does not die');

    $amq->assert_messages({
        destination => $destination,
        assert_count => 2,
    }, "Correct (2) stock messages sent for shipment");

    $amq->clear_destination($destination);

    # Shipment with three different products, should broadcast three messages
    $product_shipment = create_shipment({ how_many => 3 });

    ok($product_shipment->broadcast_stock_levels, 'Broadcast stock levels does not die');

    $amq->assert_messages({
        destination => $destination,
        assert_count => 3,
    }, "Correct (3) stock messages sent for shipment");

    $amq->clear_destination($destination);#

    # 3 products all the same (1 message)
    (undef, $pids) = Test::XTracker::Data->grab_products({
        channel => Test::XTracker::Data->channel_for_nap(),
        how_many => 1,
    });

    # We want the same PID three times
    push @{$pids}, ( $pids->[0], $pids->[0] );

    $product_shipment = Test::XTracker::Data->create_domestic_order(
        channel => Test::XTracker::Data->channel_for_nap(),
        pids    => $pids, # We only want the voucher
    )->shipments->first;

    ok($product_shipment->broadcast_stock_levels, 'Broadcast stock levels does not die');

    $amq->assert_messages({
        destination => $destination,
        assert_count => 1,
    }, "Correct (1) stock messages sent for shipment");

}

sub create_shipment {
    my $args = shift;

    my $channel = Test::XTracker::Data->channel_for_nap();

    my $build_args = {
        how_many => $args->{how_many}//1,
        channel  => $channel,
    };
    $build_args->{phys_vouchers} = { how_many => $args->{how_many}//1 }
        if $args->{phys_vouchers};
     $build_args->{virt_vouchers} = { how_many => $args->{how_many}//1 }
        if $args->{virt_vouchers};

    my (undef, $pids) = Test::XTracker::Data->grab_products($build_args);

    Test::XTracker::Data->create_domestic_order(
        channel => $channel,
        pids    => $pids
    )->shipments->first,
}

sub id_from_sku {
    my ($shipping_charge_sku) = @_;
    my $shipping_charge = $schema->resultset("Public::ShippingCharge")->search({
        sku => $shipping_charge_sku,
    })->first or die("Unknown Shipping Charge SKU ($shipping_charge_sku)\n");
    return $shipping_charge->id;
}

sub update_status_remove_hold_invalid_chars {
    my $channel = Test::XTracker::Data->channel_for_nap();
    my $address = Test::XTracker::Data->create_order_address_in('NonASCIICharacters');
    my $order_data = Test::XTracker::Data::Order->create_new_order({
        channel => $channel,
        address => $address,
    });
    my $shipment = $order_data->{shipment_object};
    ok( $shipment, 'created shipment ' . $shipment->id );
    $shipment->validate_address({operator_id => $APPLICATION_OPERATOR_ID});

    ok($shipment->is_on_hold_for_invalid_address_chars,
        "Shipment is on hold for Invalid Characters" );

    ok($shipment->shipment_status_id == $SHIPMENT_STATUS__HOLD, "shipment status is on hold");

    my $count = $shipment->discard_changes->search_related('shipment_holds', {
        shipment_hold_reason_id => $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS
    } )->count;

    is( $count, 1, "There is 1 shipment_hold record for Invalid Characters");

    # Call update_status to re-validate address
    update_shipment_status( $dbh,
                            $shipment->id,
                            $SHIPMENT_STATUS__PROCESSING,
                            $APPLICATION_OPERATOR_ID
                          );

    # shipment should be on hold
    ok( $shipment->is_on_hold_for_invalid_address_chars,
        "Shipment still on hold due to Invalid Characters" );

    $count = $shipment->discard_changes->search_related('shipment_holds', {
        shipment_hold_reason_id => $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS
    } )->count;

    is( $count, 1, "Still 1 shipment_hold record for Invalid Characters");

    # Test to check if address is updated, it gets off hold from invalid charaters
    my $valid_address = Test::XTracker::Data->create_order_address_in('current_dc_premier');
    $shipment->update({shipment_address_id => $valid_address->id});
    update_shipment_status( $dbh,
                            $shipment->id,
                            $SHIPMENT_STATUS__PROCESSING,
                            $APPLICATION_OPERATOR_ID
                          );

    $shipment->discard_changes;

    #check shipment is not on hold due to invalid charaters
    ok(!$shipment->is_on_hold_for_invalid_address_chars,
        "Shipment is NOT on hold due to Invalid Characters" );

}

sub verify_shipment_item_product_name_attribute_encoding {
    my $channel = Test::XTracker::Data->channel_for_nap();
    my $order_data = Test::XTracker::Data::Order->create_new_order( {
        channel     => $channel,
    } );
    my $shipment = $order_data->{shipment_object};

    my $schema = $shipment->result_source->schema;
    $schema->txn_do(sub {
        my $item = $shipment->shipment_items->first;
        my $product = $item->variant->product;
        my $attribute = $product->update_or_create_related('product_attribute', {
            name => '生日快乐',
        } );

        my $info = get_shipment_item_info( $schema->storage->dbh, $shipment->id );
        ok( $info, "get_shipment_item_info returned data");
        isa_ok( $info, 'HASH' );
        ok( $info->{$item->id}{name} eq $attribute->name, "Attribute name matches name in info data" );
        ok( utf8::is_utf8($info->{$item->id}->{name}), "name in info data is a character with utf8 flag" );

        $schema->txn_rollback();
    });
}

=head2 check_create_shipment_hold

Tests the 'create_shipment_hold' function:

    * That it requires a 'schema' connection rather than a 'dbh'

=cut

sub check_create_shipment_hold {

    note "Testing: 'create_shipment_hold' function";

    my $shipment = create_shipment();
    $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );
    $shipment->shipment_holds->delete;

    # get the Shipment Hold Logs in newest to oldest
    my $hold_log_rs = $shipment->shipment_hold_logs->search( {}, {
        order_by => 'id DESC',
    } );
    $hold_log_rs->delete;

    my %hold_args = (
        shipment_id     => $shipment->id,
        reason_id       => $SHIPMENT_HOLD_REASON__OTHER,
        operator_id     => $APPLICATION_OPERATOR_ID,
        comment         => 'comment',
        release_date    => '',
    );

    note "check errors are thrown when called in-properly";
    throws_ok {
            create_shipment_hold( $dbh, \%hold_args );
        }
        qr/Schema Connection.*Required/i,
        "'create_shipment_hold' throws expected error when no 'schema' connection passed in"
    ;
    throws_ok {
            my %tmp_args = %hold_args;
            delete $tmp_args{shipment_id};
            create_shipment_hold( $schema, \%tmp_args );
        }
        qr/Shipment id required/i,
        "when no 'shipment_id' passed in and error is thrown"
    ;

    note "check it works when called properly";
    lives_ok {
            create_shipment_hold( $schema, \%hold_args );
        }
        "'create_shipment_hold' lives"
    ;
    my $hold = $shipment->shipment_holds->first;
    isa_ok( $hold, 'XTracker::Schema::Result::Public::ShipmentHold',
                            "'shipment_hold' record created for Shipment" );
    cmp_ok( $hold->shipment_hold_reason_id, '==', $SHIPMENT_HOLD_REASON__OTHER,
                            "and for the expected Reason" );
    is( $hold->comment, 'comment', "and has the expected Comment" );
    cmp_ok( $hold->operator_id, '==', $APPLICATION_OPERATOR_ID,
                            "and for the expected Operator" );

    my $hold_log = $hold_log_rs->reset->first;
    isa_ok( $hold_log, 'XTracker::Schema::Result::Public::ShipmentHoldLog',
                            "A Shipment Hold Log record has been Created" );
    cmp_ok( $hold_log->shipment_hold_reason_id, '==', $SHIPMENT_HOLD_REASON__OTHER,
                            "and for the expected Reason" );
    is( $hold_log->comment, 'comment', "and has the expected Comment" );
    cmp_ok( $hold->operator_id, '==', $APPLICATION_OPERATOR_ID,
                            "and for the expected Operator" );

    return;
}

