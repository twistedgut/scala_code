#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

goods_in.t - Test the Goods In process

=head1 DESCRIPTION

Test the Goods In process.

Create a purchase order.

Select a printer station for Goods In/Stock In, get redirected to the actual
page and verify that the purchase order is listed in the correct tab.

Login in another session and look for the product in purchase order search,
verify that we can find it.

If the purchase order isn't editable in XT, verify that attempting to submit
causes an error message to be displayed about not being able to submit packing
slips for unconfirmed purchase orders, and confirm the purchase order.

Go to the purchase order overview page for the PO, and do some basic
channelisation tests.

Submit the packing slip value and verify that we have printed a delivery
(always) and a measurement form (when appropriate).

Go through the item count process, count 10 surplus items and verify that we
get a success message.

Go to the quality control page, check that we find our delivery. Open a new tab
on the qc page. Submit our items (including the surplus ones - none faulty),
and try and return to the QC page to re-submit - should get an error telling us
that QC has already been done for this delivery. Try and submit in the other
tab, and get another error message (double submit).

Verify that we have printed a I<surplus> and I<main> stock sheets.

Hit the Goods In/Surplus page and accept all the items.

Bag and tag both PGIDs.

If we're in IWS phase, send a I<stock_received> message to XT and check XT's
stock count has incremented by the right amount.

Otherwise, if we're in PRL mode scan to putaway_prep, if not do a manual
putaway (select the PGID, book it and complete it).

#TAGS goodsin qualitycontrol iws checkruncondition needswork duplication http toobig putaway bagandtag surplus purchaseorder whm

=head1 NOTES

This test started its life as a product of the MrPorter team. It has been
ported to be somewhat more modern and to use more flexible methods, but the
underlying test remains unchanged. In essence, any questions, blame Jason.

Notice the use of L<Test::XTracker::Data>->whatami.

If this test is intended to test the whole Goods In process, it should probably
cover more scenarios than it does. If not, perhaps it should attempt to cover
less.

=head1 SEE ALSO

recent_deliveries.t

=cut

use strict;
use warnings;

use FindBin::libs;


use Test::XT::Flow;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :stock_order_status
);
use XTracker::Config::Local qw(
    config_var
);
use Test::XTracker::PrintDocs;
use Test::XT::Data::Container;
use XT::Rules::Solve;

my $perms = {
    $AUTHORISATION_LEVEL__OPERATOR => [
        'Goods In/Stock In',
        'Goods In/Item Count',
        'Goods In/Surplus',
        'Goods In/Quality Control',
        'Goods In/Bag And Tag',
        'Goods In/Putaway',
        'Goods In/Putaway Prep',
    ],
    $AUTHORISATION_LEVEL__MANAGER => [
        'Stock Control/Location',
        'Stock Control/Inventory',
        'Stock Control/Purchase Order',
    ],
};

my $flow = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Location',
        'Test::XT::Data::PurchaseOrder',
        'Test::XT::Flow::GoodsIn',
        'Test::XT::Flow::StockControl',
        'Test::XT::Feature::AppMessages',
        'Test::XT::Feature::Ch11n',
        'Test::XT::Feature::Ch11n::GoodsIn',
        'Test::XT::Feature::Ch11n::StockControl',
        'Test::XT::Flow::WMS',
        'Test::XT::Flow::PrintStation',
    ],
);

my $is_dc2 = Test::XTracker::Data->whatami eq 'DC2';
my $is_dc3 = Test::XTracker::Data->whatami eq 'DC3';

#Add a second flow object to test duplicate sequencial submission on QC page (WHM-198)
my $flow1 = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Location',
        'Test::XT::Data::PurchaseOrder',
        'Test::XT::Flow::GoodsIn',
        'Test::XT::Flow::StockControl',
        'Test::XT::Feature::AppMessages',
        'Test::XT::Feature::Ch11n',
        'Test::XT::Feature::Ch11n::GoodsIn',
        'Test::XT::Feature::Ch11n::StockControl',
        'Test::XT::Flow::WMS',
        'Test::XT::Flow::PrintStation'
    ],
);

use Test::XTracker::RunCondition
    export => [qw( $iws_rollout_phase )];

if ( XTracker::Config::Local::config_var(qw/IWS rollout_phase/) ) {
    note 'Clearing all test locations';
    $flow->data__location__destroy_test_locations;
}
else {
    $flow->data__location__initialise_non_iws_test_locations;
}

my $purchase_order = Test::XTracker::Data->create_from_hash({
    channel_id      => $flow->mech->channel->id,
    placed_by       => 'Ian Docherty',
    confirmed       => 0,
    stock_order     => [{
        status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
        product         => {
            product_type_id => 61,
            style_number    => 'ICD STYLE',
            variant         => [{
                size_id         => 1,
                stock_order_item    => {
                    quantity            => 40,
                },
            }],
            product_channel => [{
                channel_id      => $flow->mech->channel->id,
            }],
            product_attribute => {
                description     => 'New Description',
            },
            price_purchase => {},
        },
    }],
});

$flow->purchase_order($purchase_order);

my $location;
if ( $is_dc2 || $is_dc3 ) {
    # DC2, DC3, use appropriate location for channel
    $location = $flow->schema->resultset('Public::Location')
        ->get_locations({ floor => 1 })
        ->first->location;
    note 'Using location ['. $location .']';
}
else {
    # non-DC2, use custom location
    $location = $flow->data__location__create_new_locations({
        quantity    => 1,
        channel_id  => $flow->mech->channel->id,
    })->[0];
    note 'Created location ['. $location .']';
}

# only one stock_order and stock_order_item in purchase order
my $variant    = $purchase_order->stock_orders->first->stock_order_items->first->variant;
my $po_items_quantity   = $purchase_order->stock_orders->first->stock_order_items->first->quantity;
my $previous_stock_quantity = ($variant->quantities->get_column('quantity')->sum||0) + 0;
my $sku        = $variant->sku;
my $product_id = $variant->product_id;


# Kick everything off by logging in
$flow
    ->login_with_permissions({
        dept => 'Distribution Management',
        perms => $perms,
    });

$flow->flow_mech__select_printer_station( {
     section => 'GoodsIn',
     subsection => 'StockIn',
    } );

$flow->flow_mech__select_printer_station_submit;
$flow
# Look for our purchase order
    ->flow_mech__goodsin__stockin
    ->test_mech__goodsin__stockin_ch11n
    ->flow_mech__goodsin__stockin_search({
        purchase_order_number => $flow->purchase_order->id
    })->test_mech__goodsin__stockin_search_ch11n;
$flow1
    ->login_with_permissions({
        dept => 'Distribution Management',
        perms => $perms,
    });
# Did we find it?
is(
    $flow->mech->as_data->{'products'}->[0]->{'PID'},
    $product_id,
    "Found our product from the purchase order search"
);

# Perform channelization tests on the Purchase Order Overview page
$flow
    ->flow_mech__stockcontrol__purchaseorder_overview( $flow->purchase_order->id )
    ->test_mech__stockcontrol__purchaseorder_overview_ch11n

# Get the packing slip
    ->flow_mech__goodsin__stockin_packingslip( $flow->stock_order->id )
    ->test_mech__goodsin__stockin_packingslip_ch11n;

# Is it sensible?
is(
    $flow->mech->as_data->{'product_data'}->{'Purchase Order'}->{'value'},
    $purchase_order->purchase_order_number,
    "Purchase order matched from Stock Order page"
);
# Submit the packing slip value
my $print_directory = Test::XTracker::PrintDocs->new();
$flow
    ->flow_mech__goodsin__stockin_packingslip__submit({ $sku => $po_items_quantity });

# Test that we've got the delivery slip, and measurement form too but only
# if it's supposed to be printed (WHM-483).
if( $variant->product->requires_measuring ) {
    my ( $delivery_slip, $measurement_form ) =
        sort { $a->file_type cmp $b->file_type }
        $print_directory->wait_for_new_files(
            files => 2
        );
    is ( $delivery_slip->file_type,    'delivery',        "Delivery slip printed" );
    is ( $measurement_form->file_type, 'measurementform', "Measurement form printed" );
} else {
    my ( $delivery_slip ) =
        $print_directory->wait_for_new_files(
            files => 1
        );
    is ( $delivery_slip->file_type,    'delivery',        "Delivery slip printed" );
}

# Submit the quantities we've 'found'
my $delivery_id = $purchase_order->stock_orders->first->deliveries->first->id;

$flow->flow_mech__select_printer_station(
    { section => 'GoodsIn', subsection => 'ItemCount', }
);
$flow->flow_mech__select_printer_station_submit;

my $surplus_quantity = 10;
my $item_count_quantity = $po_items_quantity + $surplus_quantity;
$flow
    ->flow_mech__goodsin__itemcount
    ->test_mech__goodsin__itemcount_ch11n
    ->flow_mech__goodsin__itemcount_scan( $delivery_id )
    ->test_mech__goodsin__itemcount_counts_ch11n
    ->flow_mech__goodsin__itemcount_submit_counts({
        counts => { $sku => $item_count_quantity },
        weight  => '1.5',
    })->test_mech__app_status_message__like(
        qr/Item count completed for delivery/, "Item counts reported updated" );

#Select printer station for quality control
$flow->flow_mech__select_printer_station( {
    section => 'GoodsIn',
    subsection => 'QualityControl',
} );
$flow->flow_mech__select_printer_station_submit;

$flow->flow_mech__goodsin__qualitycontrol;
$flow1->flow_mech__goodsin__qualitycontrol;
# Can we find the delivery on the QC page? Look for a link to it...
my @links = $flow->mech->look_down(
    'href',
    "/GoodsIn/QualityControl?delivery_id=$delivery_id"
);
is(scalar @links, 1, "Found a link to delivery ID [$delivery_id]");
my @links1 = $flow1->mech->look_down(
    'href',
    "/GoodsIn/QualityControl?delivery_id=$delivery_id"
);
is(scalar @links1, 1, "Found a link to delivery ID [$delivery_id]");

# Submit the quality control data for it
$flow
    ->test_mech__goodsin__qualitycontrol_ch11n
    ->flow_mech__goodsin__qualitycontrol_submit( $delivery_id );
#open a second QC page with same delivery_id in another tab (WHM-198)
$flow1
    ->test_mech__goodsin__qualitycontrol_ch11n
    ->flow_mech__goodsin__qualitycontrol_submit( $delivery_id );
$flow
    ->test_mech__goodsin__qualitycontrol_processitem_ch11n
    ->flow_mech__goodsin__qualitycontrol_processitem_submit( {
        qc => {
            'faulty_container' =>
                (Test::XT::Data::Container->get_unique_ids( { how_many => 1 } ))[0],
            $sku => { checked => $item_count_quantity, faulty => 0 },
            weight => 123,
            length => 2,
            height => 2,
            width  => 2
        },
    });
# Should no longer be available
$flow->catch_error(
    qr/Delivery \d+ is not ready for QC/,
    "Delivery is no longer ready for QC",
    flow_mech__goodsin__qualitycontrol_deliveryid => ( $delivery_id )
);
#turn off errors are fatal to be receive the error message
$flow1->errors_are_fatal(0);
$flow1
    ->test_mech__goodsin__qualitycontrol_processitem_ch11n
    ->flow_mech__goodsin__qualitycontrol_processitem_submit( {
        qc => {
            'faulty_container' =>
                (Test::XT::Data::Container->get_unique_ids( { how_many => 1 } ))[0],
            $sku => { checked => $item_count_quantity, faulty => 0 }
        }
    });

# Check printer docs have been created
$flow1->mech->has_feedback_error_ok(qr/This delivery has already been submitted, please contact your supervisor./, 'error message received for double delivery sequencial submit');
$flow1->errors_are_fatal(1);

my (@printdocs) = sort {$a->file_type cmp $b->file_type}
    $print_directory->wait_for_new_files( files => 2 );
is( scalar @printdocs, 2, 'Two printdocs returned');

my %pgid;
for my $desired_filetype (qw/main surplus/) {
    my $printdoc = shift(@printdocs);
    note "Found: " . $printdoc->full_path;

    if ( $desired_filetype eq 'main' ) {
        $pgid{main} = { id => $printdoc->file_id, count => $po_items_quantity };
    }
    else {
        $pgid{surplus} = { id => $printdoc->file_id, count => $surplus_quantity };
    }

    my $received_data = $printdoc->as_data('printdoc/putaway');
    my $received_metadata = $received_data->{metadata};

    is( $printdoc->file_type, $desired_filetype, "Print doc is of type $desired_filetype" );
    is( $received_metadata->{'page_type'}, ucfirst( $desired_filetype ), "Print doc displays correct page type: $desired_filetype" );
    my $row = $received_data->{item_list}[0];
    is( $row->{SKU}, $sku, "Print doc contains the correct SKU: $sku" );
    # We only display quantities for surplus sheets
    next unless $desired_filetype eq 'surplus';
    is( $row->{Quantity}, $pgid{surplus}{count}, 'surplus doc contains quantity' );
}

# Process surplus pgid
$flow->task__set_printer_station(qw/GoodsIn Surplus/);
$flow->flow_mech__goodsin__surplus
     ->test_mech__goodsin__surplus_ch11n
     ->flow_mech__goodsin__surplus_processgroupid( $pgid{surplus}{id} )
     ->test_mech__goodsin__surplus_process_ch11n
     ->flow_mech__goodsin__surplus_processgroupid_submit({$sku => { accepted => $pgid{surplus}{count} }});

# Well... it appears that after processing a surplus the PGID of the surplus
# items changes. This behaviour is weird and should probably be reviewed
# (seriously, wtf), but until then at least we have a regression test for it.
my ($surplus_doc) = $print_directory->wait_for_new_files( files => 1 );
is( $surplus_doc->file_type, 'accept', 'should find stock sheet for processed surplus item' );
$pgid{surplus}{id} = $surplus_doc->file_id;

for my $pgid_type ( keys %pgid ) {
    my $pgid = $pgid{$pgid_type}{id};
    note "processing $pgid_type type (PGID $pgid)";
    $flow->flow_mech__goodsin__bagandtag
         ->test_mech__goodsin__bagandtag_ch11n
         ->flow_mech__goodsin__bagandtag_submit( $pgid )
         ->flow_mech__goodsin__bagandtag_processgroupid_submit();

    if ( config_var(qw/IWS rollout_phase/) ) {
        my $sp_rs = $flow->schema
            ->resultset('Public::StockProcess')->search({ group_id => $pgid });

        $flow->flow_wms__send_stock_received(
            sp_group_rs => $sp_rs,
            operator    => $flow->mech->logged_in_as_object,
        );

        my $new_stock_quantity = $variant->quantities->get_column('quantity')->sum;
        # We're doing this in a loop, so we want to increment the previous
        # stock quantity by however many items we added, so our counts will add
        # up in the next iteration
        is( $new_stock_quantity,
            ($previous_stock_quantity += $pgid{$pgid_type}{count}),
            "New stock quantities match what was received" );
    }
    else {
        # Items going to main stock should appear on the putaway prep page with
        # PRLs enabled
        if ( config_var(qw/PRL rollout_phase/) ) {
            # We don't bother testing putaway prep - we have a whole bunch of
            # other tests doing that. Let's just check that the item can be
            # submitted
            $flow->mech__goodsin__putaway_prep
                 ->mech__goodsin__putaway_prep_submit('scan_value', $pgid );
        }
        else {
            $flow->flow_mech__goodsin__putaway
                 ->test_mech__goodsin__putaway_ch11n
                 ->flow_mech__goodsin__putaway_submit( $pgid )
                 ->flow_mech__goodsin__putaway_book_submit( $location, $pgid{$pgid_type}{count} )
                 ->flow_mech__goodsin__putaway_book_complete();
        }
    }
}

if ( ! $is_dc2 || !$is_dc3) {
    note 'Clearing all test locations';
    $flow->data__location__destroy_test_locations;
}

done_testing;
