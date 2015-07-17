#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;
use Test::XT::Flow;

use Test::More::Prefix qw/test_prefix/;
use XTracker::Constants::FromDB qw( :authorisation_level );
use XTracker::Config::Local qw( config_var sys_config_var );
use Test::XTracker::PrintDocs;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::Artifacts::Labels::MrPSticker;
use Test::XTracker::RunCondition iws_phase => 'iws', export => [qw( $iws_rollout_phase $distribution_centre )];

test_prefix("Setup");
my $xtracker_says = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

# Start-up gubbins here. Test plan follows later in the code...
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::WMS',
    ],
);
my $schema = $framework->schema;

$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
    ]},
    dept => 'Customer Care'
});

my %orders = (
    # Create a MR P order, picked
    mrp => $framework->flow_db__fulfilment__create_order_picked(
        products => 3, channel => 'mrp' ),
    # Create a MR P that we won't add a sticker to
    mrp_no_sticker => $framework->flow_db__fulfilment__create_order_picked(
        products => 3, channel => 'mrp' ),
    # Create a NAP order
    nap => $framework->flow_db__fulfilment__create_order_picked(
        products => 3, channel => 'nap' ),
);
$orders{'mrp'}->{'order_object'}->update({ sticker => 'Mr Tired' });

note( sprintf("'%s' order has shipment ID '%s'",
    $_, $orders{$_}->{'shipment_object'}->id) ) foreach keys %orders;

# Send a ready_for_printing for each
test_prefix("Printing back-and-forth");
$framework->flow_wms__send_ready_for_printing(
    shipment_id  => 's-' . $orders{$_}->{'shipment_object'}->id,
    pick_station => 40, # <-- turns into u4_mrpsticker_pick_40, which must be in config
) for keys %orders;

# Check the received printing_done messages
$xtracker_says->expect_messages({
    messages => [
        # The NAP one shouldn't have had anything printed
        {
            '@type'   => 'printing_done',
            'details' => {
                shipment_id => 's-' . $orders{'nap'}->{'shipment_object'}->id,
                printers => [],
            },
        },
        # MRP is phase-dependent, and only the one for which we set a sticker
        # should tell us it printed anything...
        {
            '@type'   => 'printing_done',
            'details' => {
                shipment_id =>
                    's-' . $orders{'mrp_no_sticker'}->{'shipment_object'}->id,
                printers => [],
            },
        },
        {
            '@type'   => 'printing_done',
            'details' => {
                shipment_id => 's-' . $orders{'mrp'}->{'shipment_object'}->id,
                printers => [
                    ( $iws_rollout_phase == 2 ) ?
                    {
                        printer_name => 'Picking MRP Printer 40', # Matches 'pick_station' above
                        documents    => [ 'MrP Sticker' ],
                    }
                    : ()
                ],
            },
        }
    ],
});

# NOW we set the sticker for no_sticker
$orders{'mrp_no_sticker'}->{'order_object'}->update({sticker => 'Mr Meerkat'});

# Shipment-ready them
test_prefix("Packing Process");
# First choose totes
(
    $orders{'nap'}->{'tote_id'},
    $orders{'mrp'}->{'tote_id'},
    $orders{'mrp_no_sticker'}->{'tote_id'}
) =
    Test::XT::Data::Container->get_unique_ids({ how_many => 3 });

# Then the messages
$framework->flow_wms__send_shipment_ready(
    shipment_id => $orders{$_}->{'shipment_object'}->id,
    container => {
        $orders{$_}->{'tote_id'} => [
            map { $_->{'sku'} } @{ $orders{$_}->{'product_objects'} } ]
    },
) for keys %orders;

undef $xtracker_says; # We don't care after this point

# The NAP one should pass through packing just fine
test_prefix("Packing NAP order");
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $orders{'nap'}->{'shipment_id'} )
    ->flow_mech__fulfilment__packing_checkshipment_submit;
    $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $_->{'sku'} ) for
        @{ $orders{'nap'}->{'product_objects'} };
$framework
    ->flow_mech__fulfilment__packing_packshipment_submit_boxes( channel_id => $orders{'nap'}->{channel_object}->id )
    ->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789")
    ->flow_mech__fulfilment__packing_packshipment_complete;

# Mr Porter cases...
# We have three things to check. How many printer log lines do we find before?
# How many afterwards? Were we given a printer-selection box?
#
# Key for test case flags:
#   undef = don't even check
#   0 = 0 messages expected (e.g. before - at picking)
#   1 = 1 message expected (e.g. after - at packing)
#
# See also XTracker::Schema::Result::Public::Shipment::list_picking_print_docs
# for more logic
for my $t (
    {
        # For the standard MRP order, it's heavily phase dependent
        name            => 'Mr P',
        order           => $orders{'mrp'},
        expected_before => $iws_rollout_phase > 1 ? undef : 0, # see key above
        expected_after  => $iws_rollout_phase > 1 ? undef : 1,
        display_box     => $iws_rollout_phase > 1 ? undef : 1,
    },
    {
        # But for a MRP order without a sticker already printed, it should
        # always prompt the packer to print some
        name            => 'Mr P (no sticker)',
        order           => $orders{'mrp_no_sticker'},
        expected_before => 0,
        expected_after  => 1,
        display_box     => 1,
    }
) {

    # We did the job testing for the sticker order in phase 2, can't do anything
    # for that in this section because it's all async now
    # Translation: We already printed at picking (for IWS)
    next unless (defined $t->{'expected_before'}
                && defined $t->{'expected_after'}
                && defined $t->{'display_box'});

    test_prefix('Packing ' . $t->{'name'} . ' order');

    # How many stickers have we already printed?
    my @before_stickers = $schema->resultset('Public::ShipmentPrintLog')->search({
        shipment_id => $t->{'order'}->{'shipment_id'},
        document    => { like => 'MRP Sticker%' }
    })->all;
    is(
        (scalar @before_stickers),
        $t->{'expected_before'},
        "Phase $iws_rollout_phase: logged " . $t->{'expected_before'} . " as printed before packing"
    );

    # Start watching for printed stickers
    my $sticker_print_directory = Test::XTracker::Artifacts::Labels::MrPSticker->new();

    # Get up the packing page
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $t->{'order'}->{'shipment_id'} );

    # Check for the printer-selection box
    my $printer_box = $framework->mech->find_xpath("id('packing_printer')")->get_node(1);
    if ( $t->{'display_box'} ) {
        ok( $printer_box, "Printer selection box shown" );
    } else {
        ok(! $printer_box, "Printer selection box removed" );
    }

    # Submit the quality control form (with the printer page on it)
    #   The printer must be set up in config:
    $framework
        ->flow_mech__fulfilment__packing_checkshipment_submit(
            $t->{'display_box'} ? ( printer => 'u4_mrpsticker_pick_40' ) : ()
        );

    # Finish the packing process
    $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $_->{'sku'} ) for
        @{ $t->{'order'}->{'product_objects'} };
    $framework
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes( channel_id => $t->{'order'}->{channel_object}->id )
        ->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789")
        ->flow_mech__fulfilment__packing_packshipment_complete;

    # Check how many printer log items we have now
    my @after_stickers = $schema->resultset('Public::ShipmentPrintLog')->search({
        shipment_id => $t->{'order'}->{'shipment_id'},
        document    => { like => 'MRP Sticker%' }
    })->all;
    is(
        (scalar @after_stickers),
        $t->{'expected_after'},
        "Phase $iws_rollout_phase: logged " . $t->{'expected_after'} . " as printed after packing"
    );

    # Check how many stickers were actually printed
    is(
        scalar($sticker_print_directory->new_files),
        $t->{'expected_after'},
        $t->{'expected_after'} . " were actually printed",
    );
}

done_testing;
