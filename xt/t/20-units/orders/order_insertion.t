#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 Tests for Inserting Orders - CANDO:132, 853

This tests the Insertion of Orders into orders table and check if the pre_auth_total_value column defaults to total_value column

Also checks the total_order_value calculated is correct, and is within threshold

=cut


use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB  qw( :currency );
use XTracker::Constants          qw( :application );
use Data::Dump  qw( pp );
use Test::XT::Data;

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );
my $dbh     = $schema->storage->dbh;
my @channels= $schema->resultset('Public::Channel')->fulfilment_only( 0 )->enabled;

foreach my $channel ( @channels ) {

    note "TEST for Sales Channel: ".$channel->name;

    my $data = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
        ],
    );

    $data->channel( $channel );     # explicitly set the Sales Channel otherwise it will default to NaP
    my $customer= $data->customer;

    my ($forget,$pids)  = Test::XTracker::Data->grab_products( {
                how_many => 1,
                channel => $channel,
        } );

    my $product     = $pids->[0];

    # Set-up options for the the Order XML file that will be created
    my $order_args  = [];
    push @{ $order_args }, {
                            customer => { id => $customer->is_customer_number },
                            order => {
                                channel_prefix => $channel->business->config_section,
                                tender_amount => 291.50,
                                shipping_price => 10,
                                shipping_tax => 1.50,
                                items => [
                                    {
                                        sku => $product->{sku},
                                        description => $product->{product}
                                                                ->product_attribute
                                                                    ->name,
                                        unit_price => 100,
                                        tax => 10,
                                        duty => 0,
                                    },
                                ],
                            },
                        };

    # Create and Parse all Order Files
    my @data_orders = Test::XTracker::Data::Order->create_order_xml_and_parse($order_args);

    foreach my $data_order ( @data_orders ) {

        # process the order
        my $order   = $data_order->digest();
        $order->allocate( $APPLICATION_OPERATOR_ID );

        isa_ok( $order, "XTracker::Schema::Result::Public::Orders", "Order Digested" );
        cmp_ok( $order->channel_id, '==', $channel->id, "sanity check: Order is for correct Sales Channel: ".$channel->id." - ".$channel->name );

        my $shipment    = $order->get_standard_class_shipment;
        my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'variant_id,voucher_variant_id' } )->all;
        cmp_ok( @ship_items, '==', 1, "One Shipment Item is Created" );

        # check out the items are what is expected

        # Normal Product
        ok( !$ship_items[0]->is_voucher, "First Shipment Item is normal product: ".$ship_items[0]->get_true_variant->sku );
        cmp_ok( $ship_items[0]->variant_id, '==', $product->{variant_id}, "First Shipment Item Variant Id is for expcected Normal Product" );


        note "Check to see if pre_auth_value column is populated with value";
        #check total_value == pre_auth_value
        cmp_ok( $order->total_value, '==', $order->pre_auth_total_value, "pre_auth_total_value is set" );


        note "Check  if get_total_value returns correct total";
        #check total order value calculates is correct
        cmp_ok( $order->total_value,'==',$order->get_total_value(), "get_total_value calculates correct total" );
        $order->update({ currency_id => $CURRENCY__USD});

        note "Check to see if order total is within threshold";
        #check total_value is within threshold
        #pre_auth_value = 121.500
        ok(!$order->is_beyond_valid_payments_threshold, "total_value is within the valid payment threshold" );

        note "Check  order is beyond  threshold limit - Negative order value";
        $ship_items[0]->update({unit_price => -143 });
        ok(!$order->is_beyond_valid_payments_threshold, "order is within threshold" );

        $ship_items[0]->update({unit_price => 200 });
        # order_value is not updated so we check against constant
        cmp_ok( 221.5,'==',$order->get_total_value(), "Calculates correct total Order Value" );
    }

}

# just remove any remaining Order XML Files
Test::XTracker::Data::Order->purge_order_directories();

done_testing;
