#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;

use Test::XTracker::RunCondition
    dc       => 'DC2';
use Test::XTracker::MessageQueue;
use Test::Exception;
use XTracker::Config::Local qw/config_var/;

use Data::Printer;

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use XTracker::Constants::FromDB qw( :pre_order_status :pre_order_note_type :pre_order_item_status );
use XTracker::Constants         qw( :application );
use XTracker::Vertex            qw( :pre_order :external_call );

my $schema  = Test::XTracker::Data->get_schema;

isa_ok( $schema, 'XTracker::Schema' );

# turn off copious output tracing from SOAP library
$XTracker::Config::Local::config{Vertex}{soap_trace} = '';


my $shipment_addresses_vertexable = { US     => 1,
                                      US2    => 0,
                                      US3    => 0,
                                      US4    => 1,
                                      Canada => 1 };

my @shipment_address_names = sort keys %{$shipment_addresses_vertexable};

ADDRESS:
foreach my $shipment_address_name ( @shipment_address_names ) {
    my $shipment_address = Test::XTracker::Data->create_order_address_in( $shipment_address_name );

    cmp_ok( $shipment_address->in_vertex_area,
            'eq',
            $shipment_addresses_vertexable->{$shipment_address_name},
           "->in_vertex_area for '$shipment_address_name' is correct" );

    my $preorder = Test::XTracker::Data::PreOrder->create_incomplete_pre_order( );

    note "Setting shipment address for test address '$shipment_address_name'";

    $preorder->update( { shipment_address_id => $shipment_address->id } );

    my $pre_vertex_total = 0;

    note "Current total_value: ".$preorder->total_value;

    note "Resetting tax and duty values for all items to zero";

    my $i = 0;
    foreach my $poi ( $preorder->pre_order_items->order_by_id->all ) {
        my $poi_nums = {
            price => $poi->unit_price,
            tax   => $poi->tax,
            duty  => $poi->duty,
        };

        note "poi[$i]: ".p($poi_nums);

        ++$i;

        $poi->update( { tax => 0, duty => 0 } );

        $pre_vertex_total += $poi->unit_price;
    }

    note "Pre-vertex total is $pre_vertex_total";

    $preorder->discard_changes;

    my $updated_total = $preorder->pre_order_items->total_value;

    cmp_ok( $pre_vertex_total, '==', $updated_total,
            "Pre-vertex total $pre_vertex_total matches updated total $updated_total" );

    note "Setting total_value to $pre_vertex_total";

    $preorder->update( { total_value => $pre_vertex_total } );

    if ($shipment_addresses_vertexable->{$shipment_address_name}) {
        ok( use_vertex_for_pre_order( $preorder ),
            "Can use Vertex for pre-order address '$shipment_address_name'" );
    }
    else {
        ok( !use_vertex_for_pre_order( $preorder ),
            "Can NOT use Vertex for pre-order address '$shipment_address_name' -- SKIPPING remaining tests" );

        next ADDRESS;
    }

    my $quotation_request = $preorder->create_vertex_quotation_request;

    ok( $quotation_request,
        "Got Vertex quotation request for pre-order with address '$shipment_address_name'");

    my $soap_call_script = config_var('Vertex', 'soap_call_script');

    ok( $soap_call_script,
        "Got external script name '$soap_call_script'" );

    # okay, now get a vertex quotation on the products via the external call mechanism
    my $quotation = do_external_soap_call( $soap_call_script, $quotation_request, $preorder );

    ok( $quotation,
        "Got Vertex quotation for pre-order with address '$shipment_address_name'");

    my $total_tax = $quotation->{QuotationResponse}{TotalTax};
    my $vertex_total = $quotation->{QuotationResponse}{Total};

    note "Total tax calculated as: $total_tax; new total: $vertex_total";

    $preorder->update_from_vertex_quotation( $quotation );

    my $new_total = $preorder->total_value;

    note "Original pre-order total: $pre_vertex_total; New pre-order total: $new_total";

    my $pre_plus_tax = ($pre_vertex_total + $total_tax);

    cmp_ok( $new_total, '==', $pre_plus_tax,
        "Order's total ($new_total) correctly represents original ($pre_vertex_total) plus with new tax amount ($total_tax)" );

    cmp_ok( $new_total, '==', $vertex_total,
        "Order's total ($new_total) correctly matches vertex's total ($vertex_total)" );
}

done_testing;

