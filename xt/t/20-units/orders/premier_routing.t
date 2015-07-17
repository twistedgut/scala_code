#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use Test::More::Prefix;

=head2 CANDO-78: London & NY Premier Routing

This tests that both DC1 & DC2 correctly get the Premier Routing Id
sent to them in the Order XML File. This is deduced from the Shipping
Charge.

=cut

use Test::XTracker::RunCondition
    dc       => [ qw( DC1 DC2 ) ];


use Test::XTracker::Hacks::TxnGuardRollback;
use Test::XTracker::Data;
use Test::XTracker::Data::Order;

use XTracker::Config::Local;
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :shipping_charge_class
                                    );

use Data::Dump  qw( pp );

use Test::XT::Data;

sub get_customer {
    my $data = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',      # should default to NaP
            'Test::XT::Data::Customer',
        ],
    );
    my $customer = $data->customer;
    return $customer;
}


my $schema = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );
my $dbh = $schema->storage->dbh;

$schema->txn_do( sub {

    # get all of the Premier Routing Id's in use by any SKU
    my @all_nominated_premier_shipping_charges = $schema->resultset("Public::ShippingCharge")->search(
        { premier_routing_id => { '!=' => undef } },
    );

    # Keep one Shipping Charge per premier_routing_id
    my %unique_nominated_premier_shipping_charge ;
    for my $shipping_charge (@all_nominated_premier_shipping_charges) {
        my $routing_id = $shipping_charge->premier_routing_id // next;
        $unique_nominated_premier_shipping_charge{$routing_id} ||= $shipping_charge;
    }
    my @premier_shipping_charges = values %unique_nominated_premier_shipping_charge;


    note "Set-up options for the the Order XML file that will be created";
    my $order_args  = [];
    my $customer = get_customer();
    for my $shipping_charge (@premier_shipping_charges) {
        note "Adding Order with SKU (" . $shipping_charge->sku . ")";
        push(
            @{ $order_args },
            {
                customer => { id => $customer->is_customer_number },
                order    => {
                    premier      => 1,
                    shipping_sku => $shipping_charge->sku,
                },
            }
        );
    }
    note "  and add an order that doesn't have a 'PREMIER_ROUTING' attribute in it";
    push @{ $order_args }, {
        customer => { id      => $customer->is_customer_number },
        order    => { premier => 0 },
    };
    note "Create and Parse all Order Files";
    my $data_orders = Test::XTracker::Data::Order->create_order_xml_and_parse(
        $order_args,
    );

    note "Loop over each Routing Option and check the Corresponding Order is Set-up correctly";
    note "Test for the Routing Options";
    for my $idx ( 0..$#premier_shipping_charges ) {
        my $shipping_charge = $premier_shipping_charges[ $idx ];
        my $data_order      = $data_orders->[ $idx ];
        note "* Testing sku (" . $shipping_charge->sku . ")";

        # process the order
        # This creates e.g. the shipping_charge
        my $order = $data_order->digest( { skip => 1 } );
        $dbh->{AutoCommit} = 0;     # needed to rollback properly

        my $premier_routing = $shipping_charge->premier_routing;
        my $premier_routing_string = "";
        $premier_routing_string = $premier_routing->description if($premier_routing);
        note "\n\n*** Testing shipping_charge (" . $shipping_charge->sku. ") (" . $shipping_charge->description . "), premier_routing ($premier_routing_string)";

        note "test for Routing Option: ".$premier_routing->id." - ".$premier_routing->description;

        # check out the 'XT::Data::Order' object
        cmp_ok(
            $data_order->premier_routing_id, '==', $premier_routing->id,
            "'premier_routing_id' value in 'XT::Data::Orders' object as expected: ".$premier_routing->id,
        );
        cmp_ok(
            $data_order->premier_routing->id, '==', $premier_routing->id,
            "record returned is the correct 'premier_routing' record",
        );
        isa_ok(
            $data_order->premier_routing,
            'XTracker::Schema::Result::Public::PremierRouting',
            "'premier_routing' method returned a record",
        );

        # check the value on the resulting shipment record
        my $shipment = $order->get_standard_class_shipment;
        cmp_ok( $shipment->premier_routing_id, '==', $premier_routing->id, "'premier_routing_id' field on 'shipment' record as expected: ".$premier_routing->id );
    }

    note "Test for NO Premier Routing in the Order File";
    my $data_order  = $data_orders->[-1];       # last order is the no Premier one
    ok( !defined $data_order->premier_routing_id, "'premier_routing_id' is undefined in 'XT::Data::Orders'" );
    ok( !defined $data_order->premier_routing, "'premier_routing' method returns 'undef'" );
    my $order       = $data_order->digest( { skip => 1 } );
    cmp_ok( $order->get_standard_class_shipment->premier_routing_id, '==', 0, "'premier_routing_id' is ZERO on 'shipment' record" );

    # rollback changes
    $schema->txn_rollback;
} );

# just remove any remaining Order XML Files
Test::XTracker::Data::Order->purge_order_directories();

done_testing;

