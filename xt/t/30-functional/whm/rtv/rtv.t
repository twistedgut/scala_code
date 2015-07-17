#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

rtv.t - Mark an item as faulty, then perform all steps from putaway to dispatch

=head1 DESCRIPTION

Visit /RTV/FaultyGI inspection request page and select a faulty item for
inspection.

Verify inspection picklist was printed.

Fill in quantities for: Fixed, RTV and Dead. Cerify one file was printed for
each of them.
    TODO: Verify what type of document was printed!

Check all the screens from Putaway to Dispatch:

    * Complete putaway
    * Request RMA
    * Send 'Here is your RMA' email
    * Select RMA
    * Update RMA number
    * List RTV
    * Pick RTV
    * Pack RTV
    * View "awaiting dispatch"
    * View shipment details
    * Update shipment details
    * View dispatched shipments

#TAGS goodsin rtv putaway iws toobig whm

=cut

use Test::XT::Flow;
use Test::XTracker::PrintDocs;
use XTracker::PrintFunctions            qw(get_printer_by_name);
use XTracker::Config::Local;

use XTracker::Constants::FromDB qw(
    :authorisation_level
    :stock_process_type
    :stock_order_status
    :delivery_status
    :std_size
    :flow_status
);

my $flow = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::PurchaseOrder',
        'Test::XT::Data::Location',
        'Test::XT::Data::RTV',
        'Test::XT::Flow::StockControl',
        'Test::XT::Flow::RTV',
        'Test::XT::Flow::GoodsIn',
        'Test::XT::Feature::Ch11n',
        'Test::XT::Feature::Ch11n::RTV',
    ],
)->new();

note 'Clear all test locations';
$flow->data__location__destroy_test_locations;

my $size_ids = Test::XTracker::Data->find_valid_size_ids(2);

# Over-ride the default purchase order and create one with a delivery.
my $purchase_order = Test::XTracker::Data->create_from_hash({
    channel_id      => $flow->mech->channel->id,
    placed_by       => 'Ian Docherty',
    stock_order     => [{
        status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
        product         => {
            product_type_id => 6,
            style_number    => 'ICD STYLE',
            variant         => [{
                size_id         => $size_ids->[0],
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
            delivery => {
                status_id   => $DELIVERY_STATUS__COUNTED,
            },
        },
    }],
});
$flow->purchase_order($purchase_order);

my $permissions = {
    $AUTHORISATION_LEVEL__OPERATOR => [
        'RTV/Faulty GI',
        'RTV/Request RMA',
        'RTV/List RMA',
        'RTV/List RTV',
        'RTV/Awaiting Dispatch',
        'RTV/Dispatched RTV',
        'RTV/Non Faulty',
        'Goods In/Putaway',
    ],
    $AUTHORISATION_LEVEL__MANAGER => [
        'RTV/Inspect Pick',
        'RTV/Pick RTV',
        'RTV/Pack RTV',
    ],
};

my $schema = Test::XTracker::Data->get_schema;
my $location_names = $flow->data__location__create_new_locations({
    quantity        => 4,
    channel_id      => $flow->mech->channel->id,
    allowed_types   => $flow->all_location_types,
});

note "locations : ". join(',',@{$location_names});

##############################
##############################

$flow->data__rtv__faultygi({
    delivery => {
        items => [
            { quantity => 40 },
        ],
    },
    qc => [
        {checked => 0, faulty => 1},
    ],
    locs => $location_names,
    putaway => [ 50 ],
});

$flow->login_with_permissions({
        dept => 'Distribution Management',
        perms => $permissions,
    });

my $print_directory = Test::XTracker::PrintDocs->new;

# Visit /RTV/FaultyGI inspection request page and select a faulty item for
# inspection
$flow->flow_mech__rtv__faultygi                     # visit /RTV/FaultyGI
        ->test_mech__rtv__faultygi_ch11n            # check correct channel display
    ->flow_mech__rtv__faultygi__submit              # select first item and submit inspection request
;#        ->test_mech__rtv__faultygi__submit_ch11n;   # check correct channel display

# Inspection picklist should have been printed
my $printer_name = get_printer_by_name("Picking - RTV Inspect")->{lp_name};
### Test for print document
my @print_dir_new_file = $print_directory->wait_for_new_files( files => 1  );
is( scalar( @print_dir_new_file ), 1, 'Correct number of files printed' );

# first file should always be delivery
is( $print_dir_new_file[0]->{file_type}, 'rtv_inspect_picklist', 'Correct file type' );
is( $print_dir_new_file[0]->{printer_name}, $printer_name, 'Sent to the correct printer' );
is( $print_dir_new_file[0]->{copies}, 1, 'Correct number of copies' );

$flow->flow_mech__rtv__inspectpick
    ->flow_mech__rtv__inspectpick__submit
    ->flow_mech__rtv__faultygi__workstation
        ->test_mech__rtv__faultygi__workstation_ch11n

# below is where it wasn't finding the product_id
    ->flow_mech__rtv__faultygi__goodsin
        ->test_mech__rtv__faultygi__goodsin_ch11n
        ->flow_mech__rtv__faultygi__goodsin__submit_quantity({description => 'description', main_qty => 1, rtv_qty => 2, dead_qty => 1});

### Test for print document
 @print_dir_new_file = sort { $a->{'file_type'} cmp $b->{'file_type'} }
    $print_directory->wait_for_new_files( files => 3  );
is( scalar( @print_dir_new_file ), 3, 'Correct number of files printed' );

$printer_name = get_printer_by_name("RTV")->{lp_name};

# first file should always be delivery
is( $print_dir_new_file[0]->{file_type}, 'dead', 'Correct file type' );
is( $print_dir_new_file[1]->{file_type}, 'main', 'Correct file type' );
is( $print_dir_new_file[2]->{file_type}, 'rtv', 'Correct file type' );
is( $print_dir_new_file[0]->{printer_name}, $printer_name, 'Sent to the correct printer' );
is( $print_dir_new_file[1]->{printer_name}, $printer_name, 'Sent to the correct printer' );
is( $print_dir_new_file[2]->{printer_name}, $printer_name, 'Sent to the correct printer' );

# now try processing too many
$flow->errors_are_fatal(0);
$flow
    ->flow_mech__rtv__faultygi__goodsin
        ->flow_mech__rtv__faultygi__goodsin__submit_quantity({description => 'description', main_qty => 10, rtv_qty => 20, dead_qty => 10, expect_failure => 1});
$flow->errors_are_fatal(1);
like($flow->mech->app_error_message(),
    qr{submitted total \d+ exceeds line quantity},
    '"submitted total exceeds line quantity" error');

# and now process the last remaining item
$flow
    ->flow_mech__rtv__faultygi__goodsin
        ->flow_mech__rtv__faultygi__goodsin__submit_quantity({description => 'description', main_qty => 0, rtv_qty => 1, dead_qty => 0});

    # That should have given us one sheet printed out. As far as I can tell,
    # the test wants to deal now with the RTV process group, so we'll pick that
    # out and get the PGID from it.

    my ($rtv_putaway_sheet) = $print_directory->new_files;

    my $rtv_pgid = $rtv_putaway_sheet->file_id;
    diag "Putaway Group [$rtv_pgid]";
    my $rtv_putaway_location = $location_names->[-1];

    if (config_var(qw/DistributionCentre name/) ne 'DC1') {
        $flow->data__location__initialise_non_iws_test_locations;
        my $location_rs = $schema->resultset('Public::Location');
        my $putaway_location = $location_rs->get_locations({ floor => 4 })
            ->search_related(
                'location_allowed_statuses',
                {'status_id'=>$FLOW_STATUS__RTV_PROCESS__STOCK_STATUS}
            )
            ->slice(0,0)->single;
        $rtv_putaway_location = $putaway_location->location->location;
    }

# We don't test for printdocs any more so let's destroy the object
$print_directory = undef;

    # Do the putaway
$flow
    ->flow_mech__goodsin__putaway_processgroupid( $rtv_pgid )
    ->flow_mech__goodsin__putaway_book_submit( $rtv_putaway_location, 1 )
    ->flow_mech__goodsin__putaway_book_complete()
    ->flow_mech__rtv__requestrma
        ->test_mech__rtv__requestrma_ch11n
    ->flow_mech__rtv__requestrma__submit
        ->test_mech__rtv__requestrma__submit_ch11n
    ->flow_mech__rtv__requestrma__create_rma_request
        ->test_mech__rtv__request_rma__email_ch11n
    ->flow_mech__rtv__requestrma__submit_email({to => 'test@example.com', message => 'Here is your RMA mail'})
        # No channelisation tests required.
    ->flow_mech__rtv__listrma
        # No channelisation tests required until form is submitted.
    ->flow_mech__rtv__listrma__submit
        ->test_mech__rtv__listrma__submit_ch11n
    ->flow_mech__rtv__listrma__view_request
        ->test_mech__rtv__listrma__view_request_summary_ch11n
    ->flow_mech__rtv__listrma__update_rma_number
        ->test_mech__rtv__listrma__view_request_details_ch11n
    ->flow_mech__rtv__listrma__capture_notes
        # Channelisation tests already done in previous stages
    ->flow_mech__rtv__create_shipment
        ->test_mech__rtv__view_shipment_details_ch11n
    ->flow_mech__rtv__listrtv
        ->test_mech__rtv__listrtv_ch11n
    ->flow_mech__rtv__pickrtv
        ->test_mech__rtv__pickrtv_ch11n
    ->flow_mech__rtv__pickrtv_autopick_and_commit
        # No channelisation tests required.
    ->flow_mech__rtv__packrtv
        # No channelisation tests required.
    ->flow_mech__rtv__packrtv_autopack_and_commit
        # No channelisation tests required.
    ->flow_mech__rtv__view_awaiting_dispatch
        ->test_mech__rtv__view_awaiting_dispatch_ch11n
    ->flow_mech__rtv__view_shipment_details
        ->test_mech__rtv__view_shipment_details_ch11n # again
    ->flow_mech__rtv__update_shipment_details
        # No channelisation tests required.
    ->flow_mech__rtv__view_dispatched_shipments
        ->test_mech__rtv__view_dispatched_shipments_ch11n
    ->flow_mech__rtv__view_dispatched_shipment_details
        ->test_mech__rtv__view_dispatched_shipment_details_ch11n
    #->flow_mech_update_rtv_actions
        # No channelisation tests required, done in previous step.
;

note 'Clearing all test locations';
$flow->data__location__destroy_test_locations;

done_testing;
1;
