#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;

use Test::XTracker::Data;
use Test::XTracker::ParamCheck;

use XTracker::Config::Local     qw( config_var );
use XTracker::Constants         qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw(
                                    :shipment_type
                                    :shipment_class
                                    :shipment_item_on_sale_flag
                                    :shipment_item_returnable_state
                                    :shipment_item_status
                                    :variant_type
                                );

use DateTime;
use Math::Round;
use Data::Dump  qw( pp );


use Test::Exception;

BEGIN {
    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Database::Shipment', qw(
                            create_shipment_item
                            get_shipment_item_info
                            get_shipment_item_by_sku
                        ) );
    use_ok('XTracker::Database::Distribution', qw(
                            check_pick_complete
                            check_shipment_item_location
                        ) );
    use_ok('NAP::Carrier');

    can_ok("XTracker::Database::Shipment", qw(
                            create_shipment_item
                            get_shipment_item_info
                            get_shipment_item_by_sku
                        ) );
    can_ok("XTracker::Database::Distribution", qw(
                            check_pick_complete
                            check_shipment_item_location
                        ) );
}

my $schema  = Test::XTracker::Data->get_schema();
my $dbh     = $schema->storage->dbh;

#---- Test Functions ------------------------------------------

_test_create_shipment_item($dbh,$schema,1);

#--------------------------------------------------------------

done_testing();

#---- TEST FUNCTIONS ------------------------------------------

# This tests creating a shipment item
sub _test_create_shipment_item {

    my $dbh     = shift;
    my $schema  = shift;

    my $tmp;
    my @tmp;
    my $id;
    my $ship_id;

    my $channel = Test::XTracker::Data->get_local_channel;
    my (undef,$pids) = Test::XTracker::Data->grab_products({
        channel_id => $channel->id,
        how_many => 1,
    });
    my ($order) = Test::XTracker::Data->create_db_order({
        pids => $pids,
    });
    my $shipment= $order->shipments->first;

    my $start_ship_items    = $shipment->shipment_items->count();
    my $variant = $schema->resultset('Public::Variant')->search( { type_id => $VARIANT_TYPE__STOCK }, { rows => 1 } )->first;
    my $ship_item= $schema->resultset('Public::ShipmentItem');
    my %item_data= (
            unit_price      => 100,
            tax             => 20,
            duty            => 10,
            status_id       => $SHIPMENT_ITEM_STATUS__NEW,
            special_order   => 'false',
        );
    my $pws_ol_id   = 1001;
    my $prod_item_id;
    my $pvouch_item_id;
    my $vvouch_item_id;
    my @item_info_keys  = qw(
                id
                shipment_id
                variant_id
                unit_price
                tax
                duty
                shipment_item_status_id
                special_order_flag
                shipment_box_id
                status
                size_id
                sku_size
                designer_size_id
                legacy_sku
                product_id
                size
                designer_size
                designer
                name
                long_description
                short_name
                colour
                weight
                sku
                returnable_state_id
                pws_ol_id
                is_hazmat
                sale_flag_id
            );


    SKIP: {
        skip "_test_create_shipment_item",1           if (!shift);

        note "Testing Create Shipment Item";

        $schema->txn_do( sub {
            #
            # normal product
            #

            # set the legacy_sku and clear any price adjustments by making them
            # out of range for the shipment
            $variant->update( { legacy_sku => $variant->sku } );
            # set some stock up
            my $prod_location   = Test::XTracker::Data->set_product_stock( {
                                                        variant_id  => $variant->id,
                                                        channel_id  => $shipment->order->channel_id,
                                                        quantity    => 10,
                                                    } );

            @tmp = $variant->product->price_adjustments;
            $tmp = $shipment->date - DateTime::Duration->new( years => 1 );
            foreach ( @tmp ) {
                $_->update( { date_start => $tmp, date_finish => $tmp } );
                $tmp    += DateTime::Duration->new( days => 1 );
            }

            $ship_id = create_shipment_item( $dbh, $shipment->id, {
                                        variant_id  => $variant->id,
                                        %item_data
                                    } );
            $prod_item_id  = $ship_id;
            cmp_ok( $ship_id, '>', 0, 'Shipment Item Created' );
            $tmp = $ship_item->find( $ship_id );
            isa_ok( $tmp, 'XTracker::Schema::Result::Public::ShipmentItem', 'Shipment Item Row' );
            cmp_ok( $tmp->variant_id, '==', $variant->id, 'Variant Id Matches' );
            ok( !defined $tmp->voucher_variant_id, 'Voucher Variant Id is not defined' );
            cmp_ok( $tmp->product_id, '==', $variant->product_id, 'Shipment Item Product Id as expected' );
            cmp_ok( $tmp->unit_price, '==', $item_data{unit_price}, 'Unit Price Matches' );
            cmp_ok( $tmp->tax, '==', $item_data{tax}, 'Tax Matches' );
            cmp_ok( $tmp->duty, '==', $item_data{duty}, 'Duty Matches' );
            #Added test for #CANDO-74
            is( $tmp->gift_recipient_email, $item_data{gift_recipient_email}, 'Recipient Email  Matches' );

            cmp_ok( $tmp->shipment_item_status_id, '==', $item_data{status_id}, 'Status Id Matches' );
            ok( !defined $tmp->pws_ol_id, 'PWS OL Id is not defined' );
            ok( !$tmp->special_order_flag, 'Special Order Flag Matches' );
            cmp_ok( $tmp->returnable_state_id, '==', $SHIPMENT_ITEM_RETURNABLE_STATE__YES,
                                                "Returnable Flag is Default 'YES' when not specified" );
            ok( !defined $tmp->link_shipment_item__price_adjustment, 'No Price Adjustment Link' );
            cmp_ok( $tmp->is_physical_voucher, '==', 0, 'Shipment Item for a Product is not a Physical Voucher' );
            cmp_ok( $tmp->is_virtual_voucher, '==', 0, 'Shipment Item for a Product is not a Virtual Voucher' );

            cmp_ok( $tmp->sale_flag_id,
                    '==',
                    $SHIPMENT_ITEM_ON_SALE_FLAG__NO,
                    "On sale flag defaults to 'No' when not specified" );

            # used to control order the ship id is returned in later tests
            $item_data{status_id}   = $SHIPMENT_ITEM_STATUS__PICKED;

            # explictly set the Returnable State Id as 'Yes'
            $item_data{returnable_state_id}  = $SHIPMENT_ITEM_RETURNABLE_STATE__YES;
            $item_data{sale_flag_id} = $SHIPMENT_ITEM_ON_SALE_FLAG__YES;

            # create shipment item with legacy sku
            $tmp = create_shipment_item( $dbh, $shipment->id, {
                                        sku     => $variant->legacy_sku,
                                        %item_data
                                    } );
            cmp_ok( $tmp, '>', $ship_id, 'New Shipment Item Id is > than previous' );
            $ship_id    = $tmp;
            $tmp = $ship_item->find( $ship_id );
            isa_ok( $tmp, 'XTracker::Schema::Result::Public::ShipmentItem', 'Legacy SKU: Shipment Item Row' );
            cmp_ok( $tmp->variant_id, '==', $variant->id, 'Variant Id Matches when using legacy sku' );
            cmp_ok( $tmp->returnable_state_id, '==', $SHIPMENT_ITEM_RETURNABLE_STATE__YES,
                                                "Returnable Flag is 'YES' when explictly specified as Yes" );
            cmp_ok( $tmp->sale_flag_id,
                    '==',
                    $SHIPMENT_ITEM_ON_SALE_FLAG__YES,
                    "On Sale flag is 'Yes' when explicitly set" );

            # explictly set the Returnable State Id as 'CC Only'
            $item_data{returnable_state_id}  = $SHIPMENT_ITEM_RETURNABLE_STATE__CC_ONLY;

            # insert a price adjustment
            $id = $variant->product->create_related( 'price_adjustments', {
                                            percentage  => 50,
                                            date_start  => ( $shipment->date - DateTime::Duration->new( days => 1 ) ),
                                            date_finish => ( $shipment->date + DateTime::Duration->new( days => 1 ) ),
                                            exported    => 0,
                                            category_id => 1,
                                        } )->id;
            # create shipment item with price adjustment and also pass a PWL OL Id
            $tmp = create_shipment_item( $dbh, $shipment->id, {
                                        variant_id  => $variant->id,
                                        %item_data,
                                        pws_ol_id   => $pws_ol_id,
                                    } );
            cmp_ok( $tmp, '>', $ship_id, 'New Shipment Item Id is > than previous' );
            $ship_id    = $tmp;
            $tmp = $ship_item->find( $ship_id );
            isa_ok( $tmp, 'XTracker::Schema::Result::Public::ShipmentItem', 'Price Adjustment: Shipment Item Row' );
            isa_ok( $tmp->link_shipment_item__price_adjustment, 'XTracker::Schema::Result::Public::LinkShipmentItemPriceAdjustment', 'New Shipment Item has a Link to Price Adjustment' );
            cmp_ok( $tmp->pws_ol_id, '==', $pws_ol_id, 'PWS OL Id Matches' );
            cmp_ok( $tmp->link_shipment_item__price_adjustment->price_adjustment_id, '==', $id, 'Shipment Item Price Adjustment Id is correct' );
            cmp_ok( $tmp->returnable_state_id, '==', $SHIPMENT_ITEM_RETURNABLE_STATE__CC_ONLY,
                                                "Returnable Flag is 'CC Only' when explictly specified" );

            # used to control order the ship id is returned in later tests
            $item_data{status_id}   = $SHIPMENT_ITEM_STATUS__NEW;

            #
            # voucher products
            #
            $pws_ol_id++;
            $item_data{returnable_state_id}  = $SHIPMENT_ITEM_RETURNABLE_STATE__NO;

            # create virtual voucher first for later tests
            my $vvoucher    = Test::XTracker::Data->create_voucher( { channel_id => $shipment->order->channel_id, is_physical => 0 } );
            my $vouch_code  = $vvoucher->create_related( 'codes', { code => 'THISISATEST'.$vvoucher->id } );
            my $vvouch_code = $vouch_code;  # store code for Virtual Voucher
            $vvouch_item_id    = create_shipment_item( $dbh, $shipment->id, {
                                        voucher_variant_id  => $vvoucher->variant->id,
                                        %item_data,
                                        gift_from   => 'FROM Virtual',
                                        gift_to     => 'TO Virtual',
                                        gift_message=> 'MESSAGE Virtual',
                                        pws_ol_id   => $pws_ol_id,
                                        gift_recipient_email => 'recipient_email@email.com',
                                    } );
            cmp_ok( $vvouch_item_id, '>', $ship_id, 'Virtual Voucher: Shipment Item Id > than previous normal Shipment Item Id' );
            $tmp = $ship_item->find( $vvouch_item_id );
            isa_ok( $tmp, 'XTracker::Schema::Result::Public::ShipmentItem', 'Virtual Voucher: Shipment Item Row' );
            ok( !defined $tmp->variant_id, 'Virtual Voucher: Variant Id is not defined' );
            cmp_ok( $tmp->voucher_variant_id, '==', $vvoucher->variant->id, 'Virtual Voucher: Voucher Variant Id Matches' );
            cmp_ok( $tmp->product_id, '==', $vvoucher->id, 'Virtual Voucher: Shipment Item Product Id as expected' );
            cmp_ok( $tmp->unit_price, '==', $item_data{unit_price}, 'Virtual Voucher: Unit Price Matches' );
            cmp_ok( $tmp->tax, '==', $item_data{tax}, 'Virtual Voucher: Tax Matches' );
            cmp_ok( $tmp->duty, '==', $item_data{duty}, 'Virtual Voucher: Duty Matches' );
            cmp_ok( $tmp->shipment_item_status_id, '==', $item_data{status_id}, 'Virtual Voucher: Status Id Matches' );
            is( $tmp->gift_from, 'FROM Virtual', 'Virtual Voucher: Gift From as expected' );
            is( $tmp->gift_to, 'TO Virtual', 'Virtual Voucher: Gift TO as expected' );
            is( $tmp->gift_message, 'MESSAGE Virtual', 'Virtual Voucher: Gift Message as expected' );
            #Added test for #CANDO-74
            is( $tmp->gift_recipient_email, 'recipient_email@email.com', 'Virtual Voucher: Gift Recipient Email as expected' );
            cmp_ok( $tmp->pws_ol_id, '==', $pws_ol_id, 'Virtual Voucher: PWS OL Id Matches' );
            ok( !$tmp->special_order_flag, 'Virtual Voucher: Special Order Flag Matches' );
            cmp_ok( $tmp->returnable_state_id, '==', $SHIPMENT_ITEM_RETURNABLE_STATE__NO,
                                                'Virtual Voucher: Returnable Flag Matches' );
            ok( !defined $tmp->link_shipment_item__price_adjustment, 'Virtual Voucher: No Price Adjustment Link' );
            cmp_ok( $tmp->is_physical_voucher, '==', 0, 'Virtual Voucher: Shipment Item NOT for a Physical Voucher' );
            cmp_ok( $tmp->is_virtual_voucher, '==', 1, 'Virtual Voucher: Shipment Item for a Virtual Voucher' );

            # create physical voucher
            my $pvoucher    = Test::XTracker::Data->create_voucher( { channel_id => $shipment->order->channel_id } );
            $vouch_code     = $pvoucher->create_related( 'codes', { code => '1_THISISATEST'.$pvoucher->id } );
            my $pvouch_code = $vouch_code;  # store code for Physical Voucher
            # set some stock up
            my $vouch_location  = Test::XTracker::Data->set_voucher_stock( {
                                                        voucher => $pvoucher,
                                                        quantity=> 10,
                                                    } );
            $tmp = create_shipment_item( $dbh, $shipment->id, {
                                        voucher_variant_id  => $pvoucher->variant->id,
                                        %item_data,
                                        gift_from   => 'FROM Physical',
                                        gift_to     => 'TO Physical',
                                        gift_message=> 'MESSAGE Physical',
                                        pws_ol_id   => ++$pws_ol_id,
                                    } );
            cmp_ok( $tmp, '>', $vvouch_item_id, 'Physical Voucher: Shipment Item Id > than previous Virtual Voucher Item Id' );
            $ship_id = $tmp;
            $pvouch_item_id = $ship_id;
            $tmp = $ship_item->find( $ship_id );
            isa_ok( $tmp, 'XTracker::Schema::Result::Public::ShipmentItem', 'Physical Voucher: Shipment Item Row' );
            ok( !defined $tmp->variant_id, 'Physical Voucher: Variant Id is not defined' );
            cmp_ok( $tmp->voucher_variant_id, '==', $pvoucher->variant->id, 'Physical Voucher: Voucher Variant Id Matches' );
            cmp_ok( $tmp->product_id, '==', $pvoucher->id, 'Physical Voucher: Shipment Item Product Id as expected' );
            cmp_ok( $tmp->unit_price, '==', $item_data{unit_price}, 'Physical Voucher: Unit Price Matches' );
            cmp_ok( $tmp->tax, '==', $item_data{tax}, 'Physical Voucher: Tax Matches' );
            cmp_ok( $tmp->duty, '==', $item_data{duty}, 'Physical Voucher: Duty Matches' );
            cmp_ok( $tmp->shipment_item_status_id, '==', $item_data{status_id}, 'Physical Voucher: Status Id Matches' );
            is( $tmp->gift_from, 'FROM Physical', 'Physical Voucher: Gift From as expected' );
            is( $tmp->gift_to, 'TO Physical', 'Physical Voucher: Gift TO as expected' );
            is( $tmp->gift_message, 'MESSAGE Physical', 'Physical Voucher: Gift Message as expected' );
            cmp_ok( $tmp->pws_ol_id, '==', $pws_ol_id, 'Physical Voucher: PWS OL Id Matches' );
            ok( !$tmp->special_order_flag, 'Physical Voucher: Special Order Flag Matches' );
            cmp_ok( $tmp->returnable_state_id, '==', $SHIPMENT_ITEM_RETURNABLE_STATE__NO,
                                                'Physical Voucher: Returnable Flag Matches' );
            ok( !defined $tmp->link_shipment_item__price_adjustment, 'Physical Voucher: No Price Adjustment Link' );
            cmp_ok( $tmp->is_physical_voucher, '==', 1, 'Physical Voucher: Shipment Item for a Physical Voucher' );
            cmp_ok( $tmp->is_virtual_voucher, '==', 0, 'Physical Voucher: Shipment Item NOT for a Virtual Voucher' );

            #
            # check you can pull back the shipment item info
            #
            note "Checking get_shipment_item_info()";
            my $ship_items  = get_shipment_item_info( $dbh, $shipment->id );
            isa_ok( $ship_items, 'HASH', 'Got a HASH Ref of Items' );
            cmp_ok( scalar( keys %{ $ship_items } ), '==', $start_ship_items + 5, 'Number of Items returned as Expected' );
            ok( exists($ship_items->{$prod_item_id}), 'Normal Product Item is found' );
            $tmp    = $ship_items->{$prod_item_id};
            map { ok( exists( $tmp->{$_} ), "Product Item: Key Found $_" ) } @item_info_keys;
            is( $tmp->{name}, $variant->product->product_attribute->name, 'Product: Name as expected' );
            is( $tmp->{long_description}, $variant->product->product_attribute->long_description, 'Product: Long Description as expected' );
            is( $tmp->{short_name}, $variant->product->product_attribute->size_scheme->short_name, 'Product: Short Name as expected' );
            cmp_ok( $tmp->{variant_id}, '==', $variant->id, 'Product: Variant Id as expected' );
            cmp_ok( $tmp->{unit_price}, '==', $item_data{unit_price}, 'Product: Unit Price Matches' );
            cmp_ok( $tmp->{weight}, '==', $variant->product->shipping_attribute->weight, 'Product: Weight as expected' );
            is( $tmp->{sku}, $variant->sku, 'Product: SKU as expected' );

            ok( exists($ship_items->{$pvouch_item_id}), 'Physical Voucher Product Item is found' );
            $tmp    = $ship_items->{$pvouch_item_id};
            map { ok( exists( $tmp->{$_} ), "Physical Voucher Item: Key Found $_" ) } ( @item_info_keys, 'voucher', 'is_physical', 'voucher_code_id', 'voucher_code', 'gift_from', 'gift_to', 'gift_message' );
            is( $tmp->{name}, $pvoucher->name, 'Physical Voucher: Name as expected' );
            is( $tmp->{long_description}, $pvoucher->name, 'Physical Voucher: Long Description as expected' );
            is( $tmp->{short_name}, '', 'Physical Voucher: Short Name as expected' );
            is( $tmp->{voucher_code}, '', 'Physical Voucher: Voucher Code is empty string' );
            cmp_ok( $tmp->{is_physical}, '==', 1, 'Physical Voucher: is Physical' );
            cmp_ok( $tmp->{variant_id}, '==', $pvoucher->variant->id, 'Physical Voucher: Variant Id as expected' );
            cmp_ok( $tmp->{unit_price}, '==', $item_data{unit_price}, 'Physical Voucher: Unit Price Matches' );
            cmp_ok( $tmp->{weight}, '>', 0, 'Physical Voucher: Weight greater than zero' );      # check there is something in the conf file
            cmp_ok( $tmp->{weight}, '==', $pvoucher->weight, 'Physical Voucher: Weight as expected' );
            is( $tmp->{designer}, 'Gift Card', 'Physical Voucher: Designer as expected - '.$pvoucher->designer );
            is( $tmp->{sku}, $pvoucher->variant->sku, 'Physical Voucher: SKU as expected' );

            #
            # check you can pull back a shipment item by sku
            #
            note "Checking get_shipment_item_by_sku()";
            $tmp = get_shipment_item_by_sku( $dbh, $shipment->id, $variant->sku );
            cmp_ok( $tmp, '==', $prod_item_id, "Product Item: Found Shipment Item Id" );
            $tmp = get_shipment_item_by_sku( $dbh, $shipment->id, $pvoucher->variant->sku );
            cmp_ok( $tmp, '==', $pvouch_item_id, "Physical Voucher: Found Shipment Item Id" );

            #
            # test check_shipment_item_location function
            #
            note "Checking check_shipment_item_location()";
            # Product
            $tmp    = check_shipment_item_location( $dbh, $prod_item_id, $prod_location->id );
            cmp_ok( $tmp, '==', 3, "Product Item: check_shipment_item_location flag is 3" );
            $prod_location->quantities->search( { variant_id => $variant->id } )->update( { quantity => 1 } );
            $tmp    = check_shipment_item_location( $dbh, $prod_item_id, $prod_location->id );
            cmp_ok( $tmp, '==', 2, "Product Item: check_shipment_item_location flag is 2" );
            $prod_location->quantities->search( { variant_id => $variant->id } )->update( { quantity => 0 } );
            $tmp    = check_shipment_item_location( $dbh, $prod_item_id, $prod_location->id );
            cmp_ok( $tmp, '==', 1, "Product Item: check_shipment_item_location flag is 1" );
            $prod_location->quantities->search( { variant_id => $variant->id } )->delete;
            $tmp    = check_shipment_item_location( $dbh, $prod_item_id, $prod_location->id );
            cmp_ok( $tmp, '==', 1, "Product Item: check_shipment_item_location flag is 1 when no quantity at location" );
            # Voucher
            $tmp    = check_shipment_item_location( $dbh, $pvouch_item_id, $vouch_location->id );
            cmp_ok( $tmp, '==', 3, "Physical Voucher: check_shipment_item_location flag is 3" );

            #
            # now use a Virtual Voucher and do similar checks
            #
            $ship_items  = get_shipment_item_info( $dbh, $shipment->id );
            ok( exists($ship_items->{$vvouch_item_id}), 'Virtual Voucher Product Item is found' );
            $tmp    = $ship_items->{$vvouch_item_id};
            map { ok( exists( $tmp->{$_} ), "Virtual Voucher Item: Key Found $_" ) } ( @item_info_keys, 'voucher', 'is_physical', 'voucher_code_id', 'voucher_code', 'gift_from', 'gift_to', 'gift_message' );
            cmp_ok( $tmp->{is_physical}, '==', 0, 'Virtual Voucher: is NOT Physical' );
            is( $tmp->{designer}, 'Virtual Gift Card', 'Virtual Voucher: Designer as expected - '.$vvoucher->designer );
            is( $tmp->{voucher_code}, '', 'Virtual Voucher: Voucher Code is empty string' );
            cmp_ok( $tmp->{weight}, '==', 0, 'Virtual Voucher: Weight as expected - should be zero' );
            # get shipment item id by sku
            $tmp = get_shipment_item_by_sku( $dbh, $shipment->id, $vvoucher->variant->sku );
            cmp_ok( $tmp, '==', $vvouch_item_id, "Virtual Voucher: Found Shipment Item Id" );
            # check shipment item location
            $tmp    = check_shipment_item_location( $dbh, $vvouch_item_id, $vouch_location->id );
            cmp_ok( $tmp, '==', 1, "Virtual Voucher: check_shipment_item_location flag is 1 as it shouldn't have any stock" );

            #
            # check if pick is complete, by checking that all Shipment Item statuses are at least
            # at the PICKED stage, this should exclude the status of the Virtual Voucher Shipment Item.
            #
            note "Checking check_pick_complete()";
            $shipment->discard_changes;
            $ship_items = $shipment->shipment_items;
            # update all statuses to PICKED
            $ship_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED } );
            cmp_ok( check_pick_complete( $dbh, $shipment->id ), '==', 1, 'Pick Complete with all items PICKED' );
            cmp_ok( $shipment->is_pick_complete, '==', 1, 'Shipment Method - Pick Complete with all items PICKED' );
            # set the product shipment item to be SELECTED
            $ship_item->find( $prod_item_id )->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED } );
            cmp_ok( check_pick_complete( $dbh, $shipment->id ), '==', 0, 'Pick Incomplete with Product Item not PICKED' );
            cmp_ok( $shipment->is_pick_complete, '==', 0, 'Shipment Method - Pick Incomplete with Product Item not PICKED' );
            $ship_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED } );
            $ship_item->find( $pvouch_item_id )->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED } );
            cmp_ok( check_pick_complete( $dbh, $shipment->id ), '==', 0, 'Pick Incomplete with Physical Voucher Item not PICKED' );
            cmp_ok( $shipment->is_pick_complete, '==', 0, 'Shipment Method - Pick Incomplete with Physical Voucher Item not PICKED' );
            $ship_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED } );
            $ship_item->find( $vvouch_item_id )->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED } );
            cmp_ok( check_pick_complete( $dbh, $shipment->id ), '==', 1, 'Pick Complete with Virtual Voucher Item not PICKED' );
            cmp_ok( $shipment->is_pick_complete, '==', 1, 'Shipment Method - Pick Complete with Virtual Voucher Item not PICKED' );

            #
            # check 'find_by_sku_and_item_status' resultset method
            # for shipment
            #
            note "Testing resultset 'search_by_sku_and_item_status' method";
            $shipment->discard_changes;

            # check using Normal Product
            $tmp    = $shipment->shipment_items->search_by_sku_and_item_status( $variant->sku, $SHIPMENT_ITEM_STATUS__PICKED );
            isa_ok( $tmp->first, 'XTracker::Schema::Result::Public::ShipmentItem', "Normal Product: 'search_by_sku_and_item_status' found Item" );
            cmp_ok( $tmp->first->variant_id, '==', $variant->id, "Normal Product: Variant Id matches" );
            cmp_ok( $tmp->first->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED, "Normal Product: Shipment Item Status Id matches" );
            # check using Physical Voucher
            $tmp    = $shipment->shipment_items->search_by_sku_and_item_status( $pvoucher->sku, $SHIPMENT_ITEM_STATUS__PICKED );
            isa_ok( $tmp->first, 'XTracker::Schema::Result::Public::ShipmentItem', "Physical Voucher: 'search_by_sku_and_item_status' found Item" );
            cmp_ok( $tmp->first->voucher_variant_id, '==', $pvoucher->variant->id, "Physical Voucher: Voucher Variant Id matches" );
            cmp_ok( $tmp->first->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PICKED, "Physical Voucher: Shipment Item Status Id matches" );
            # check using Virtual Voucher
            $tmp    = $shipment->shipment_items->search_by_sku_and_item_status( $vvoucher->sku, $SHIPMENT_ITEM_STATUS__SELECTED );
            isa_ok( $tmp->first, 'XTracker::Schema::Result::Public::ShipmentItem', "Virtual Voucher: 'search_by_sku_and_item_status' found Item" );
            cmp_ok( $tmp->first->voucher_variant_id, '==', $vvoucher->variant->id, "Virtual Voucher: Voucher Variant Id matches" );
            cmp_ok( $tmp->first->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__SELECTED, "Virtual Voucher: Shipment Item Status Id matches" );

            #
            # check 'order_by_sku' resultset method
            #
            note "Testing resultset 'order_by_sku' method";
            $shipment->discard_changes;
            @tmp    = ();
            $tmp    = $shipment->shipment_items;
            while ( my $item = $tmp->next ) {
                push @tmp, {
                            ship_id => $item->id,
                            sort_on => [ split( /-/, $item->get_true_variant->sku ) ],
                            sku => $item->get_true_variant->sku,
                        };
            }
            # sort the shipment items how they should be after 'order_by_sku' has been called
            my @sorted_items    = sort { $a->{sort_on}[0] <=> $b->{sort_on}[0] || $a->{sort_on}[1] <=> $b->{sort_on}[1] } @tmp;
            # make the call and then compare the two arrays
            @tmp    = $shipment->shipment_items->order_by_sku->all;
            foreach ( 0..$#tmp ) {
                my $got_sku     = $tmp[ $_ ]->get_true_variant->sku;
                my $expected_sku= shift( @sorted_items )->{sku};
                is( $got_sku, $expected_sku, "'order_by_sku' Arr. Index: $_, Ship Item: ".$tmp[ $_ ]->id." has expected SKU: ".$got_sku );
            }

            #
            # check total weight of shipment
            #
            note "Testing Total Weight of Shipment";
            $shipment->discard_changes;
            my @all_items   = $shipment->shipment_items->all;
            my $total_weight= 0;
            foreach my $item ( @all_items ) {
                if ( defined $item->variant_id ) {
                    $total_weight   += nearest( .001, $item->variant->product->shipping_attribute->weight );
                }
                else {
                    $total_weight   += nearest( .001, $item->voucher_variant->product->weight );
                }
            }
            cmp_ok( $shipment->total_weight, '==', $total_weight, 'Shipment Total Weight as expected' );

            #
            # check QC'ing Voucher Codes
            #
            note "Check QC'ing Voucher Codes for Shipment Items";
            # set-up data first
            my @ship_ids    = ( $pvouch_item_id );      # store shipment item ids
            my @vouch_codes = ( $vouch_code );          # store voucher code objects
            # Create a couple more codes for the same Voucher
            push @vouch_codes, $pvoucher->create_related( 'codes', { code => '2_THISISATEST'.$pvoucher->id } );
            push @vouch_codes, $pvoucher->create_related( 'codes', { code => '3_THISISATEST'.$pvoucher->id } );
            # create another shipment item for the voucher
            $tmp    = create_shipment_item( $dbh, $shipment->id, {
                                        voucher_variant_id  => $pvoucher->variant->id,
                                        %item_data,
                                        gift_from   => 'FROM Physical',
                                        gift_to     => 'TO Physical',
                                        gift_message=> 'MESSAGE Physical',
                                        pws_ol_id   => ++$pws_ol_id,
                                        gift_recipient_email => 'recipient_email@email.com',
                                    } );
            push @ship_ids, $tmp;       # store the shipment item id for later use
            # create another Physical voucher along with a code and a Shipment Item for it
            $pvoucher   = Test::XTracker::Data->create_voucher( { channel_id => $shipment->order->channel_id, value => 500 } );
            push @vouch_codes, $pvoucher->create_related( 'codes', { code => '4_THISISATEST'.$pvoucher->id } );
            $tmp    = create_shipment_item( $dbh, $shipment->id, {
                                        voucher_variant_id  => $pvoucher->variant->id,
                                        %item_data,
                                        gift_from   => 'FROM Physical',
                                        gift_to     => 'TO Physical',
                                        gift_message=> 'MESSAGE Physical',
                                        pws_ol_id   => ++$pws_ol_id,
                                    } );
            push @ship_ids, $tmp;       # store the shipment item id for later use
            # create another voucher but don't create a shipment item for it
            $pvoucher   = Test::XTracker::Data->create_voucher( { channel_id => $shipment->order->channel_id, value => 250 } );
            my $vouch_not_used  = $pvoucher->create_related( 'codes', { code => '5_THISISATEST'.$pvoucher->id } );

            # get the latest changes
            $shipment->discard_changes;
            $ship_items = $shipment->shipment_items;

            # do the tests
            #   @vouch_codes has:
            #     0 - Voucher Code for Voucher and one of the Shipment Items
            #     1 - Voucher Code for same Voucher as '0' and for one of the Shipment Items
            #     2 - Voucher Code for same Voucher as '0' but shouldn't be assigned to any shipment item
            #                      because there are only enough for 2 shipment items
            #     3 - Voucher Code for a different Voucher and assigned to a Shipment Item
            #   @ship_ids has:
            #     0 - Shipment Item for Voucher for $vouch_codes[ 0 to 2 ]
            #     1 - Shipment Item for Voucher same as '0' for $vouch codes[ 0 to 2 ]
            #     2 - Shipment Item for Voucher different from previous 2 for $vouch_codes[3]

            # failures
            # 'qc' context
            note "'qc' context Failures";
            $tmp    = $ship_items->check_voucher_code( { for => 'qc', vcode => 'sdfjsldflj' } );
            ok( !$tmp->{success} && $tmp->{err_no} == 1, "Failure: Using invalid voucher code" );
            $tmp    = $ship_items->check_voucher_code( { for => 'qc', vcode => $vouch_not_used->code } );
            ok( !$tmp->{success} && $tmp->{err_no} == 3, "Failure: Using valid voucher code but not for one of the shipment items" );
            $vouch_not_used->update( { assigned => DateTime->now() } );
            $tmp    = $ship_items->check_voucher_code( { for => 'qc', vcode => $vouch_not_used->code } );
            ok( !$tmp->{success} && $tmp->{err_no} == 2, "Failure: Voucher Code found but already assigned" );
            $tmp    = $ship_items->check_voucher_code( { for => 'qc', vcode => $vouch_codes[0]->code,
                                                            chkd_codes => { $vouch_codes[0]->code => $vouch_codes[0] } } );
            ok( !$tmp->{success} && $tmp->{err_no} == 4, "Failure: Voucher Code has already been QC'd" );
            $tmp    = $ship_items->check_voucher_code( {
                                                        for => 'qc',
                                                        vcode => $vouch_codes[2]->code,
                                                        chkd_codes => {
                                                            $vouch_codes[0]->code => $vouch_codes[0],
                                                            $vouch_codes[1]->code => $vouch_codes[1],
                                                        },
                                                        chkd_items => {
                                                            $ship_ids[0] => 1,
                                                            $ship_ids[1] => 1,
                                                        },
                                                   } );
            ok( !$tmp->{success} && $tmp->{err_no} == 5, "Failure: Voucher Code for a Shipment Item but all of those types have been QC'd" );

            # 'packing' context
            note "'packing' context Failures";
            $tmp    = $ship_items->check_voucher_code( {
                                                        for => 'packing',
                                                        vcode => $vouch_codes[0]->code,
                                                        qced_codes => {
                                                                $vouch_codes[1]->code => 1,
                                                                $vouch_codes[2]->code => 1,
                                                                $vouch_codes[3]->code => 1,
                                                            },
                                                     } );
            ok( !$tmp->{success} && $tmp->{err_no} == 6, "Failure: Voucher Code not in list of QC'd codes" );
            $tmp    = $ship_items->check_voucher_code( {
                                                        for => 'packing',
                                                        vcode => $vouch_codes[0]->code,
                                                        qced_codes => { $vouch_codes[0]->code => 1 },
                                                        shipment_item_id => $ship_ids[2],
                                                     } );
            ok( !$tmp->{success} && $tmp->{err_no} == 7, "Failure: Valid Voucher Code but for wrong Shipment Item" );
            my $tmp_si  = $ship_items->find( $ship_ids[2] );
            $tmp_si->update( { voucher_code_id => $vouch_codes[0]->id } );
            $tmp    = $ship_items->check_voucher_code( {
                                                        for => 'packing',
                                                        vcode => $vouch_codes[3]->code,
                                                        qced_codes => { $vouch_codes[3]->code => 1 },
                                                        shipment_item_id => $ship_ids[2],
                                                     } );
            ok( !$tmp->{success} && $tmp->{err_no} == 8, "Failure: Shipment Item already has Voucher Assigned" );
            $tmp_si->update( { voucher_code_id => undef } );

            # successes
            # 'qc' context
            note "'qc' context Successes";
            my $chkd_codes  = {};
            my $chkd_items  = {};
            my $qced_codes  = {};   # used for 'packing' context
            $tmp    = $ship_items->check_voucher_code( { for => 'qc', vcode => $vouch_codes[3]->code } );
            ok( $tmp->{success}, "Success: Voucher Code ok when it's the first one to be QC'd with NO QC'd Code or Item params passed" );
            cmp_ok( $tmp->{voucher_code}->id, '==', $vouch_codes[3]->id, "Success: Voucher Code returned as expected" );
            cmp_ok( $tmp->{shipment_item}->id, '==', $ship_ids[2], "Success: Shipment Item returned as expected" );
            $tmp    = $ship_items->check_voucher_code( { for => 'qc', vcode => $vouch_codes[3]->code,
                                                            chkd_codes => $chkd_codes, chkd_items => $chkd_items } );
            ok( $tmp->{success}, "Success: Voucher Code ok when it's the first one to be QC'd WITH QC'd Code and Item params passed" );
            ok( exists( $chkd_codes->{ $vouch_codes[3]->code } ), "Success: Voucher Code found in 'chkd_codes' as expected" );
            ok( exists( $chkd_items->{ $ship_ids[2] } ), "Success: Shipment Item found in 'chkd_items' as expected" );

            # 'packing' context
            $chkd_codes     = {};
            $chkd_items     = {};
            note "'packing' context Successes";
            $tmp    = $ship_items->check_voucher_code( {
                                                        for => 'packing',
                                                        vcode => $vouch_codes[2]->code,
                                                        qced_codes => { $vouch_codes[2]->code => 1 },
                                                        shipment_item_id => $ship_ids[1],
                                                     } );
            ok( $tmp->{success}, "Success: Voucher Code ok when the first call with no previously checked params passed" );
            cmp_ok( $tmp->{voucher_code}->id, '==', $vouch_codes[2]->id, "Success: Voucher Code returned as expected" );
            cmp_ok( $tmp->{shipment_item}->id, '==', $ship_ids[1], "Success: Shipment Item returned as expected" );
            $tmp    = $ship_items->check_voucher_code( {
                                                        for => 'packing',
                                                        vcode => $vouch_codes[1]->code,
                                                        chkd_codes => $chkd_codes,
                                                        chkd_items => $chkd_items,
                                                        qced_codes => { $vouch_codes[1]->code => 1 },
                                                        shipment_item_id => $ship_ids[0],
                                                     } );
            ok( $tmp->{success}, "Success: Voucher Code ok when the first call with Checked Code or Item params passed" );
            cmp_ok( $tmp->{voucher_code}->id, '==', $vouch_codes[1]->id, "Success: Voucher Code returned as expected" );
            cmp_ok( $tmp->{shipment_item}->id, '==', $ship_ids[0], "Success: Shipment Item returned as expected" );
            ok( exists( $chkd_codes->{ $vouch_codes[1]->code } ), "Success: Voucher Code found in 'chkd_codes' as expected" );
            ok( exists( $chkd_items->{ $ship_ids[0] } ), "Success: Shipment Item found in 'chkd_items' as expected" );


            # go through a series of calls simulating real world use and then test structures at the end
            note "Testing Series of calls for QC'ing of Vouchers";
            $chkd_codes  = {};
            $chkd_items  = {};
            $tmp    = $ship_items->check_voucher_code( { for => 'qc', vcode => $vouch_codes[3]->code,
                                                            chkd_codes => $chkd_codes, chkd_items => $chkd_items } );
            ok( $tmp->{success}, "Series: 1st Call Success" );
            $tmp    = $ship_items->check_voucher_code( { for => 'qc', vcode => $vouch_codes[1]->code,
                                                            chkd_codes => $chkd_codes, chkd_items => $chkd_items } );
            ok( $tmp->{success}, "Series: 2nd Call Success" );
            $tmp    = $ship_items->check_voucher_code( { for => 'qc', vcode => $vouch_codes[0]->code,
                                                            chkd_codes => $chkd_codes, chkd_items => $chkd_items } );
            ok( $tmp->{success}, "Series: 3rd Call Success" );
            cmp_ok( $chkd_codes->{ $vouch_codes[3]->code }, '==', $ship_ids[2], "Series: 'chkd_codes' has first Voucher" );
            cmp_ok( $chkd_codes->{ $vouch_codes[1]->code }, '==', $ship_ids[0], "Series: 'chkd_codes' has second Voucher" );
            cmp_ok( $chkd_codes->{ $vouch_codes[0]->code }, '==', $ship_ids[1], "Series: 'chkd_codes' has third Voucher" );
            is( $chkd_items->{ $ship_ids[2] }, $vouch_codes[3]->code, "Series: 'chkd_items' has first shipment id" );
            is( $chkd_items->{ $ship_ids[0] }, $vouch_codes[1]->code, "Series: 'chkd_items' has second shipment id" );
            is( $chkd_items->{ $ship_ids[1] }, $vouch_codes[0]->code, "Series: 'chkd_items' has third shipment id" );
            # now just check a supsequent call should fail
            $tmp    = $ship_items->check_voucher_code( { for => 'qc', vcode => $vouch_codes[2]->code,
                                                            chkd_codes => $chkd_codes, chkd_items => $chkd_items } );
            ok( !$tmp->{success} && $tmp->{err_no} == 5, "Series Failure: Voucher Code for a Shipment Item but all of those types have been QC'd" );
            $tmp    = $ship_items->check_voucher_code( { for => 'qc', vcode => $vouch_codes[0]->code,
                                                            chkd_codes => $chkd_codes, chkd_items => $chkd_items } );
            ok( !$tmp->{success} && $tmp->{err_no} == 4, "Series Failure: Voucher Code has already been QC'd" );

            note "Testing Series of call for Packing Vouchers";
            $chkd_codes  = {};
            $chkd_items  = {};
            $qced_codes  = { map { ( $_->code => 1 ) } ( $vouch_codes[0], $vouch_codes[1], $vouch_codes[3] ) };
            # to store the results to check later
            my @res;
            # make life easier in simulating the real world updates
            $shipment->discard_changes;
            my @ship_items  = map { $shipment->shipment_items->find( $_ ) } @ship_ids;
            $res[0] = $ship_items->check_voucher_code( { for => 'packing', vcode => $vouch_codes[3]->code, shipment_item_id => $ship_ids[2],
                                                            chkd_codes => $chkd_codes, chkd_items => $chkd_items, qced_codes => $qced_codes } );
            $vouch_codes[3]->update( { assigned => DateTime->now() } );
            $ship_items[2]->update( { voucher_code_id => $vouch_codes[3]->id } );
            $res[1] = $ship_items->check_voucher_code( { for => 'packing', vcode => $vouch_codes[0]->code, shipment_item_id => $ship_ids[1],
                                                            chkd_codes => $chkd_codes, chkd_items => $chkd_items, qced_codes => $qced_codes } );
            $vouch_codes[0]->update( { assigned => DateTime->now() } );
            $ship_items[1]->update( { voucher_code_id => $vouch_codes[0]->id } );
            $res[2] = $ship_items->check_voucher_code( { for => 'packing', vcode => $vouch_codes[1]->code, shipment_item_id => $ship_ids[0],
                                                            chkd_codes => $chkd_codes, chkd_items => $chkd_items, qced_codes => $qced_codes } );
            $vouch_codes[1]->update( { assigned => DateTime->now() } );
            $ship_items[0]->update( { voucher_code_id => $vouch_codes[1]->id } );
            map { ok( $res[$_]{success}, "Series: Call ".($_+1)." was a 'success'" ) } 0..$#res;
            ok( $res[0]{voucher_code}->code eq $vouch_codes[3]->code && $res[0]{shipment_item}->id == $ship_ids[2],
                        "Series: Call 1 returned Voucher Code & Shipment Item as expected" );
            ok( $res[1]{voucher_code}->code eq $vouch_codes[0]->code && $res[1]{shipment_item}->id == $ship_ids[1],
                        "Series: Call 2 returned Voucher Code & Shipment Item as expected" );
            ok( $res[2]{voucher_code}->code eq $vouch_codes[1]->code && $res[2]{shipment_item}->id == $ship_ids[0],
                        "Series: Call 3 returned Voucher Code & Shipment Item as expected" );
            cmp_ok( $chkd_codes->{ $vouch_codes[3]->code }, '==', $ship_ids[2], "Series: 'chkd_codes' has first Voucher" );
            cmp_ok( $chkd_codes->{ $vouch_codes[0]->code }, '==', $ship_ids[1], "Series: 'chkd_codes' has second Voucher" );
            cmp_ok( $chkd_codes->{ $vouch_codes[1]->code }, '==', $ship_ids[0], "Series: 'chkd_codes' has third Voucher" );
            is( $chkd_items->{ $ship_ids[2] }, $vouch_codes[3]->code, "Series: 'chkd_items' has first shipment id" );
            is( $chkd_items->{ $ship_ids[1] }, $vouch_codes[0]->code, "Series: 'chkd_items' has second shipment id" );
            is( $chkd_items->{ $ship_ids[0] }, $vouch_codes[1]->code, "Series: 'chkd_items' has third shipment id" );
            # now just check a supsequent call should fail
            $tmp    = $ship_items->check_voucher_code( { for => 'packing', vcode => $vouch_codes[3]->code, shipment_item_id => $ship_ids[2],
                                                            chkd_codes => $chkd_codes, chkd_items => $chkd_items, qced_codes => $qced_codes } );
            ok( !$tmp->{success} && $tmp->{err_no} == 2, "Series Failure: Voucher Code has already been assigned" );
            $qced_codes->{ $vouch_codes[2]->code }  = 1;
            $tmp    = $ship_items->check_voucher_code( { for => 'packing', vcode => $vouch_codes[2]->code, shipment_item_id => $ship_ids[1],
                                                            chkd_codes => $chkd_codes, chkd_items => $chkd_items, qced_codes => $qced_codes } );
            ok( !$tmp->{success} && $tmp->{err_no} == 8, "Series Failure: Shipment Item already assigned a Voucher Code" );
            $tmp    = $ship_items->check_voucher_code( { for => 'packing', vcode => $vouch_codes[2]->code, shipment_item_id => $ship_ids[2],
                                                            chkd_codes => $chkd_codes, chkd_items => $chkd_items, qced_codes => $qced_codes } );
            ok( !$tmp->{success} && $tmp->{err_no} == 7, "Series Failure: Valid Voucher Code but not for the wrong SKU for the Shipment Item" );

            # call 'get_shipment_item_info' again to check
            # Voucher Codes show up in the data
            note "Testing Voucher Codes show up in 'get_shipment_item_info' call";
            $shipment->discard_changes;
            $shipment->shipment_items->find( $pvouch_item_id )->update( { voucher_code_id => $pvouch_code->id } );
            $shipment->shipment_items->find( $vvouch_item_id )->update( { voucher_code_id => $vvouch_code->id } );
            $tmp    = get_shipment_item_info( $dbh, $shipment->id );
            cmp_ok( $tmp->{ $pvouch_item_id }{voucher_code_id}, '==', $pvouch_code->id, "Physical Voucher Code Id correct: ".$pvouch_code->id );
            is( $tmp->{ $pvouch_item_id }{voucher_code}, $pvouch_code->code, "Physical Voucher Code correct: ".$pvouch_code->code );
            cmp_ok( $tmp->{ $vvouch_item_id }{voucher_code_id}, '==', $vvouch_code->id, "Virtual Voucher Code Id correct: ".$vvouch_code->id );
            is( $tmp->{ $vvouch_item_id }{voucher_code}, $vvouch_code->code, "Virtual Voucher Code correct: ".$vvouch_code->code );

            # set voucher codes back to being NULL for following tests
            $shipment->shipment_items->find( $pvouch_item_id )->update( { voucher_code_id => undef } );
            $shipment->shipment_items->find( $vvouch_item_id )->update( { voucher_code_id => undef } );

            #
            # now check you can't have a voucher code
            # without a voucher variant id on the shipment_item table
            #
            $shipment->discard_changes;
            $tmp = $ship_item->find( $pvouch_item_id );
            note "Testing when you can and can't assign a voucher code to a shipment_item row";
            lives_ok( sub {
                $tmp->update( { voucher_code_id => $vouch_code->id } );
            },'voucher_code_id with voucher_variant_id and no variant_id is fine' );

            $schema->svp_begin('shipment_item_test');
            dies_ok( sub {
                $tmp->update( { voucher_variant_id => undef, variant_id => $variant->id } );
            }, 'voucher_code_id with no voucher_variant_id but with variant_id is not fine' );
            $schema->svp_rollback('shipment_item_test');

            lives_ok( sub {
                $tmp->update( { voucher_code_id => undef, voucher_variant_id => undef, variant_id => $variant->id } );
            }, 'no voucher_code_id with no voucher_variant_id but with a variant_id is fine' );

            # just test you must have a variant (voucher or normal)
            dies_ok( sub {
                $tmp->update( { variant_id => undef } );
            }, 'no voucher_variant_id and no variant_id is not fine' );

            # undo any changes
            $schema->txn_rollback();
        } );

    }
}

#--------------------------------------------------------------
