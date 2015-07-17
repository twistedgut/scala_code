#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

fulfilment_pigeonhole_single.t - Test the packing process with pigeon holes (IWS only)

=head1 DESCRIPTION

Test the packing process with pigeon holes (IWS only).

#TAGS fulfilment packing iws checkruncondition whm

=cut

use FindBin::libs;

use Test::XTracker::RunCondition iws_phase => 'iws', dc => 'DC1', export => qw( $iws_rollout_phase );


use Test::XT::Flow;
use XTracker::Constants::FromDB qw( :authorisation_level );
use XTracker::Database qw(:common);
use Test::XTracker::LocationMigration;
use Test::XTracker::Data qw/qc_fail_string/;
use Test::XT::Data::Container;
use Test::Differences;
use Test::XTracker::Artifacts::RAVNI;
use JSON::XS;
use XTracker::Config::Local 'config_var';

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::PipePage',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::WMS',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Selection'
    ]}
});
my $schema = Test::XTracker::Data->get_schema;

# Create the order with five products
my $product_count = 1;
my $product_data =
    $framework->flow_db__fulfilment__create_order_selected(
        products => $product_count,
        channel  => 'NAP',
        premier => 1,
    );
my $shipment_id = $product_data->{'shipment_id'};
my ($p_container_id) = Test::XT::Data::Container->get_unique_ids({
    how_many => 1,
    prefix   => 'PH7357',
});

my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
my $wms_to_xt = Test::XTracker::Artifacts::RAVNI->new('wms_to_xt');

# Save a LocationMigration test for each variant
my @location_migration_tests;
for my $product ( @{ $product_data->{'product_objects'} } ) {
    my $test = Test::XTracker::LocationMigration->new(
        variant_id => $product->{'variant_id'}, debug => 0
    );
    $test->snapshot("Before picking");
    push( @location_migration_tests, $test );
}


# Fake a ShipmentReady from IWS
$framework->flow_wms__send_shipment_ready(
    shipment_id => $shipment_id,
    container => {
        $p_container_id => [ map { $_->{'sku'} } @{ $product_data->{'product_objects'} }[0] ],
    },
);

# Validate the message we faked.
$wms_to_xt->expect_messages({
    messages => [
        {
            '@type'   => 'shipment_ready',
            'details' => { 'shipment_id' => "s-$shipment_id", },
        }
    ]
});


for my $test ( @location_migration_tests ) {
    $test->snapshot("After picking");
    $test->test_delta(
        from => "Before picking",
        to   => "After picking",
        location   => { DC1 => -1 },
        stock_status => { 'Main Stock' => -1 },
    );
}


# Pack the items

$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $shipment_id );

# Assert we sent a shipment-received to IWS
$xt_to_wms->expect_messages({
    messages => [
        {
            'type'   => 'shipment_received',
        },
    ]
});

#print $framework->mech->uri()."\ncontinue?\n"; my $s=<>;
my @items_to_fail = @{$framework->mech->as_data()->{shipment_items}};

my $fail_reason = 'Fail' . rand(100000000);

# Let's QC fail the item whilst packing and provide a reason
$framework->errors_are_fatal(0);
$framework
    ->flow_mech__fulfilment__packing_checkshipment_submit(
        fail => {
            $items_to_fail[0]->{'shipment_item_id'} => $fail_reason,
        }
);
is($framework->mech->uri->path,
   '/Fulfilment/Packing/PlaceInPEtote',
   'pack QC fail requires putting items into another tote');
is($framework->mech->app_error_message,
     "Please return pigeon hole items to their original pigeon holes and take any labels and paperwork to the packing exception desk",
     'packer asked to send shipment to exception desk');
$framework->errors_are_fatal(1);

my ($petote)=Test::XT::Data::Container->get_unique_ids({ how_many => 1 });

for my $i (@items_to_fail) {
    my $container = $schema->resultset('Public::Container')->find($i->{Container});
    if ($container->is_pigeonhole()) {
        $framework
            ->flow_mech__fulfilment__packing_placeinpetote_scan_item($i->{SKU})
            ->flow_mech__fulfilment__packing_placeinpetote_pigeonhole_confirm($container->id);
    } else {
        $framework
            ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $i->{SKU} )
            ->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $petote );
    }
}
#$framework->debug_http(2);
$framework->flow_mech__fulfilment__packing_placeinpetote_mark_complete();

# fail messages should incorporate our name now, so find that
my $operator_name = $framework->mech->app_operator_name();

# Make our items data structure reflect these QC fails
@items_to_fail = map { $_->{'QC'} = 'Ok'; $_; } @items_to_fail;
$items_to_fail[0]->{'QC'} = qc_fail_string($fail_reason,  $operator_name);

$framework
    ->flow_mech__fulfilment__packingexception
    ->flow_mech__fulfilment__packingexception_submit( $shipment_id );

$xt_to_wms->expect_messages({
    messages => [
        {
            'type'   => 'shipment_reject',
        },
    ]
});
# Take SKU and QC and shove them in a temp data structure, and sort
# that so we can compare more nicely
sub cleanup {
    my @ret=
        # Sort first by SKU and then by fail reason. We use both
        # because we may ahve more than one SKU
        sort {
            $a->{'sku'} cmp $b->{'sku'} ||
                $a->{'qc'} cmp $b->{'qc'}
            }
            # Take just the information we want
            map {
                { 'sku' => $_->{'SKU'}, 'qc' => $_->{'QC'} }
            } @_;
    return @ret;
}

my @received_exception_items = cleanup(
    @{$framework->mech->as_data()->{shipment_items}});

my @expected_exception_items = cleanup(@items_to_fail);

eq_or_diff( \@received_exception_items, \@expected_exception_items,
       "Exception screen shows right data");


#print $framework->mech->uri()."\ncontinue?\n"; my $s=<>;
$framework->flow_mech__fulfilment__packing_checkshipmentexception_ok_sku( $items_to_fail[0]->{'shipment_item_id'});
$framework->flow_mech__fulfilment__packing_checkshipmentexception_submit;


# Pack the items
$framework
    ->flow_mech__fulfilment__packing()
    ->flow_mech__fulfilment__packing_submit( $shipment_id );

# Validate in the DB that the QC failure reason as been wiped.
my $shipment_items_fixed_count = $schema->resultset('Public::ShipmentItem')->search(
    { shipment_id => $shipment_id, qc_failure_reason => undef })->count;

is($shipment_items_fixed_count,$product_count,"QC failure reason is back to undef");

$framework->flow_mech__fulfilment__packing_checkshipment_submit();

for my $item (@{ $product_data->{'product_objects'} }) {
    my $sku      = $item->{'sku'};
    $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $sku );
}

#Pack the items

$framework
    ->flow_mech__fulfilment__packing_packshipment_submit_boxes( channel_id => $product_data->{channel_object}->id )
    ->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789")
    ->flow_mech__fulfilment__packing_packshipment_complete;

for my $test ( @location_migration_tests ) {
    $test->snapshot("After packing");
    $test->test_delta(
        from => "Before picking",
        to   => "After packing",
        location   => { DC1 => -1 },
        stock_status => { 'Main Stock' => -1 },
    );
}

$xt_to_wms->expect_messages({
    messages => [
        {
            'type'   => 'shipment_wms_pause',
            'details' => { shipment_id => "s-$shipment_id",
                           pause      => JSON::XS::false }
        },
        {
            'type'   => 'shipment_received',
            'details' => { shipment_id => "s-$shipment_id" }
        },
        {
            'type'   => 'shipment_packed',
            'details' => { shipment_id => "s-$shipment_id" }
        },
    ]
});


done_testing();
