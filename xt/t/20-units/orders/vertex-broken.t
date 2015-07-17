#!/usr/bin/env perl

# just like the main vertex test, but uses broken addresses instead

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
use XTracker::Constants::Reservations qw( :reservation_messages );
use XTracker::Constants         qw( :application );
use XTracker::Vertex            qw( :pre_order );

my $schema  = Test::XTracker::Data->get_schema;

isa_ok( $schema, 'XTracker::Schema' );

# turn off copious output tracing from SOAP library
$XTracker::Config::Local::config{Vertex}{soap_trace} = '';

run_tests('vertex/do-soap-call.pl');    # with the external mechanism
run_tests('');                          # without it

sub run_tests {
    my $config_value = shift;

    note "Running tests with soap_call_script set to '$config_value'";

    $XTracker::Config::Local::config{Vertex}{soap_call_script} = $config_value;

    my @shipment_address_names = ( qw( US_broken ) );

    foreach my $shipment_address_name ( @shipment_address_names ) {
        my $preorder = Test::XTracker::Data::PreOrder->create_incomplete_pre_order( );
        my $shipment_address = Test::XTracker::Data->create_order_address_in( $shipment_address_name );

        note "Setting shipment address for broken address '$shipment_address_name'";

        $preorder->update( { shipment_address_id => $shipment_address->id } );

        ok( !use_vertex_for_pre_order( $preorder ),
            "Can NOT use Vertex for broken pre-order address '$shipment_address_name'" );

        # but we carry on anyway, because we're testing brokenness handling

        my $quotation_request = $preorder->create_vertex_quotation_request;

        ok( $quotation_request,
            "Got Vertex quotation request for pre-order with broken address '$shipment_address_name'");

        # okay, try to get a vertex quotation on the products
        try {
            my $quotation = $preorder->create_vertex_quotation;

            ok( !$quotation,
                "Unexpectedly got Vertex quotation for pre-order with broken address '$shipment_address_name'");
        }
        catch {
            # let's see if the remangled error came through okay
            # -- 'postcode' won't be in the original, but it will be in the
            #    remangled one
            like( $_, qr/Unable to find any applicable tax areas.*postcode=/sm,
                  "Succesfully complained about a broken address, and remangled it in the process");
        };
    }
}

done_testing;

