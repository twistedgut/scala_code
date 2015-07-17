#!/usr/bin/env perl

=head1 NAME

putaway.t - Putaway quarantined stock ("Non-faulty")

=head1 DESCRIPTION

Send InventoryAdjust message to IWS, to put some stock in transit.

Quarantine the stock, selecting "Non-Faulty".

Try to putaway a greater quantity that exists, verify the error is caught.

Complete putaway for the stock.

Verify that stock levels remain consistent if stock is placed in quarantine,
with "non-faulty" selected.

Verify that the putaway quantity is the same as the amount we intended to
putaway.

#TAGS goodsin rtv putaway iws whm

=cut

use strict;
use warnings;
use FindBin::libs;
use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw( :authorisation_level :rtv_action);
use Test::XT::Flow::Easy # Exports $flow
    runconditions => [iws_phase => 'iws'],
    permissions   => ['Goods In', 'Stock Control', 'RTV'];

# Make sure we have some products
my $product = (Test::XTracker::Data->create_test_products({
    how_many     => 1,
    ensure_stock => 1,
    channel_id   => Test::XTracker::Data->channel_for_business(name=>'nap')->id,
}))[0];
Test::XTracker::Data->ensure_variants_stock( $product->id );
my $variant = $product->variants->first();

# Make sure we have a delivery we can use
Test::XTracker::Data->create_delivery_for_po(
    # Create a purchase order for the product, and get its ID
    Test::XTracker::Data->setup_purchase_order(
        [ $product->id ],
        { create_stock_order_items_for_all_variants => 1 }
    )->id,
    'putaway'
);

note "Using product: " . $product->id;
note "Using variant: " . $variant->id;

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Location',
        'Test::XT::Flow::GoodsIn',
        'Test::XT::Flow::StockControl::Quarantine',
        'Test::XT::Flow::RTV',
        'Test::XT::Feature::LocationMigration'
    ],
);
$framework->login_with_permissions({
    perms => {
        $AUTHORISATION_LEVEL__MANAGER => [
            'Goods In/Putaway',
            'Stock Control/Inventory',
            'Stock Control/Quarantine',
        ]
    }
});


# Issue a msg from IWS to put those in Transit
$flow->flow_wms__send_inventory_adjust(
    sku             => $variant->sku,
    quantity_change => -10,
    reason => 'STOCK OUT TO XT',
    stock_status => 'main',
);

# Quarantine, selecting Non-Faulty
$flow
    ->flow_mech__stockcontrol__inventory_stockquarantine( $product->id );

my ($quantity_object ,$process_group_id) = $flow
    ->flow_mech__stockcontrol__inventory_stockquarantine_submit(
        variant_id => $variant->id,
        location   => 'Transit',
        quantity   => 2,
        type       => 'V',
    );

my $putaway_location = $flow->data__location__create_new_locations({
    quantity    => 1,
    channel_id  => Test::XTracker::Data->channel_for_business(name=>'nap')->id,
})->[0];


#Putaway
$flow
    ->flow_mech__goodsin__putaway_processgroupid( $process_group_id );

$framework
    ->flow_mech__goodsin__putaway_processgroupid( $process_group_id );
$flow
    ->flow_mech__goodsin__putaway_book_submit( $putaway_location, 2 );

$framework->errors_are_fatal(0);

$framework
    ->flow_mech__goodsin__putaway_book_submit( $putaway_location, 2 );

$framework->mech->has_feedback_error_ok(qr/Quantity entered \(2\) is greater than the quantity remaining for putaway \(0\)/);

$framework->errors_are_fatal(1);

$framework
    ->flow_mech__goodsin__putaway_book_complete();

## Check putaway quantity for this stock process
my $schema  = Test::XTracker::Data->get_schema;

#check log_rtv_stock
my $rtv_log = $schema->resultset('Public::LogRtvStock')->search({
                                                                variant_id    => $variant->id,
                                                                rtv_action_id => $RTV_ACTION__PUTAWAY__DASH__RTV_PROCESS
                                                        })->first;
cmp_ok ( $rtv_log->quantity , '==', 2 , "Logged correct quantity");

done_testing;



