#!/usr/bin/env perl

use NAP::policy "tt", qw( test );

=head1 NAME

measurements.t - Test measurements functionality

=head1 DESCRIPTION

Test some of the measurements functionality on two pages:

    * /StockControl/Measurement
    * /GoodsIn/QualityControl?delivery_id=...

Check that the correct measurement types are displayed for the product's
classification and channel, and that they can be updated.

#TAGS needswork poorcoverage goodsin loops intermittentfailure qualitycontrol purchaseorder inventory whm

=head1 TODO

Define the business rules for whether or not a channel should have measurements.

=cut

use strict;
use warnings;

use Test::XT::Flow;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :stock_order_status
);
use Test::XTracker::Data;
use Test::XTracker::PrintDocs;
use Test::XT::Data::Container;

use XT::Rules::Solve;
use XTracker::PrinterMatrix;

my $perms = {
    $AUTHORISATION_LEVEL__OPERATOR => [
        'Goods In/Stock In',
        'Goods In/Item Count',
        'Goods In/Surplus',
        'Goods In/Quality Control',
        'Goods In/Bag And Tag',
        'Goods In/Putaway',
    ],
    $AUTHORISATION_LEVEL__MANAGER => [
        'Stock Control/Measurement',
    ],
};

my $schema = Test::XTracker::Data->get_schema;
foreach my $channel ($schema->resultset('Public::Channel')->enabled_channels()->all) {
    test_measurements_for_channel($channel);
}

sub test_measurements_for_channel {
    my ($channel) = @_;

    my $flow = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Data::Location',
            'Test::XT::Data::PurchaseOrder',
            'Test::XT::Data::Measurements',
            'Test::XT::Flow::GoodsIn',
            'Test::XT::Flow::StockControl',
            'Test::XT::Feature::Measurements',
            'Test::XT::Flow::PrintStation',
        ],
    );

    note 'Clearing all test locations';
    $flow->data__location__destroy_test_locations;

    $flow->mech->channel($channel);
    note "Testing measurements for channel id ".$channel->id;

    my $purchase_order = Test::XTracker::Data->create_from_hash({
        channel_id      => $flow->mech->channel->id,
        placed_by       => 'Measurements Test',
        confirmed       => 1,
        stock_order     => [{
            status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
            product         => {
                classification_id   => 1,   # accessories
                product_type_id     => 1,   # bags have different measurements across channels
                style_number        => 'ICD STYLE',
                variant             => [{
                    size_id             => 1,   # sadly we can't have size constants
                    stock_order_item    => {
                        quantity            => 40,
                    },
                }],
                product_channel     => [{
                    channel_id          => $flow->mech->channel->id,
                }],
                product_attribute   => {
                    description         => 'New Description',
                    name                => 'Test Product Name',
                },
                price_purchase      => {},
            },
        }],
    });

    $flow->purchase_order($purchase_order);

    my $measurement_types = $flow->attr__measurements__measurement_types;

    unless ($measurement_types && scalar @$measurement_types) {
        # If a new channel is added it might or might not be supposed to have
        # measurements. Warn if it doesn't. If measurements disappear for all
        # existing channels this test will fail because no tests are run, so
        # that at least should be obvious.
        note "No measurement types for product type ".$flow->product->product_type->product_type." (id ".$flow->product->product_type_id.") on channel ".$flow->mech->channel->name." (id ".$flow->mech->channel->id.")";
        note "Testing aborted for channel ".$flow->mech->channel->id.", if you think measurements should have been set up for it you might want to investigate.";
        return;
    }

    # Kick everything off by logging in
    $flow->login_with_permissions({
            dept => 'Distribution Management',
            perms => $perms,
    });

    my $location = $flow->data__location__create_new_locations({
        quantity    => 1,
    })->[0];

    # only one stock_order and stock_order_item in purchase order
    my $variant    = $purchase_order->stock_orders->first->stock_order_items->first->variant;
    my $quantity   = $purchase_order->stock_orders->first->stock_order_items->first->quantity;
    my $sku        = $variant->sku;
    my $product    = $variant->product;

    # stop it looking like it's on the website, so that the code doesn't
    # try to connect to the web db to update the size info there, because
    # that won't work on hudson
    $variant->product->product_channel->update({
        'live' => 0,
        'staging' => 0,
    });

    note 'Created location ['. $location .']';

    $flow->flow_mech__select_printer_station( {
        section => 'GoodsIn',
        subsection => 'StockIn',
        } );

    $flow->flow_mech__select_printer_station_submit;

    # Look for our purchase order
    $flow->flow_mech__goodsin__stockin
        ->flow_mech__goodsin__stockin_search({
            purchase_order_number => $flow->purchase_order->id
        });

    # Get the packing slip
    $flow->flow_mech__goodsin__stockin_packingslip( $flow->stock_order->id );

    {
    my $print_directory = Test::XTracker::PrintDocs->new();

    # Submit the packing slip value
    $flow->flow_mech__goodsin__stockin_packingslip__submit({ $sku => $quantity });

    my $print_measurement_form = $product->requires_measuring ? 1 : 0;
    my @print_dir_new_file = $print_directory->wait_for_new_files( files => 1 + $print_measurement_form );

    is( scalar( @print_dir_new_file ), 1 + $print_measurement_form, 'Correct number of files printed' );

    ok( scalar( grep { $_->{file_type} eq 'delivery' } @print_dir_new_file),
        'Correct file type'
    ) or diag explain map { $_->{file_type} } @print_dir_new_file;

    is( $print_dir_new_file[0]->{copies}, 1, 'Correct number of copies' );
    }
    $flow->task__set_printer_station(qw/GoodsIn ItemCount/);

    # Submit the quantities we've 'found'
    my $delivery_id = $purchase_order->stock_orders->first->deliveries->first->id;
    $flow
        ->flow_mech__goodsin__itemcount
        ->flow_mech__goodsin__itemcount_scan( $delivery_id )
        ->flow_mech__goodsin__itemcount_submit_counts({
            counts  => { $sku => 50 },
            weight  => '1.5',
    });

    #Select printer station for quality control
    $flow->flow_mech__select_printer_station( {
        section => 'GoodsIn',
        subsection => 'QualityControl',
    } );

    $flow->flow_mech__select_printer_station_submit;

    # Test measurements displayed on QC page
    $flow->flow_mech__goodsin__qualitycontrol_deliveryid($delivery_id);
    note $flow->mech->uri;
    $flow->test_mech__goodsin__qualitycontrol_measurements();

    # Update measurements
    $flow->flow_mech__goodsin__qualitycontrol_processitem_submit({
        measurements => $flow->attr__measurements__variant_measurement_values,
        qc         => {
            weight  => 16,
            length  => 2,
            width   => 2,
            height  => 2
        },
    });

    # Test measurements displayed on stock control measurement page
    $flow->flow_mech__stockcontrol__measurement();
    $flow->flow_mech__stockcontrol__measurement_submit();
    $flow->test_mech__stockcontrol__measurement();

    # Update measurements and test correct values are displayed
    $flow->data__measurements__update_variant_measurement_values();
    $flow->flow_mech__stockcontrol__measurement_edit_submit({
        'measurements'=>$flow->attr__measurements__variant_measurement_values
    });
    $flow->flow_mech__stockcontrol__measurement();
    $flow->flow_mech__stockcontrol__measurement_submit();
    $flow->test_mech__stockcontrol__measurement();

    note 'Clearing all test locations';
    $flow->data__location__destroy_test_locations;
}

done_testing;
