#!/usr/bin/env perl

=head1 NAME

pipeo_2_extraneous_items.t - Test the PIPE-O page ("Place In Packing Exception, Orphan")

=head1 DESCRIPTION

    Create 5 regular products, 2 vouchers

    Create an order of products excluding a regular PID P5 and a voucher P7
    We will want these two to be dealt with as Orphans

    Pack all of these in to tote T1
    Get a tote T2 which will be used for the Orphan items

    We're going to throw an extra strayed item (P5) in T2 too

    Fake a ShipmentReady from IWS
    Place some extra items in a container
    Vreify message: Please scan unexpected item
    We should now be at the PIPE-O page
    PIPE-O'ing 2/3 canceled items
        We're leaving one cancelled item in the tote on purpose
    Mark process as done and mark the tote as emtpy

    Verify correct number of strayed skus in the tote
    Verify route message -> packing exception

#TAGS fulfilment packing packingexception duplication checkruncondition iws whm

=head1 SEE ALSO

pipeo.t

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::RunCondition
    dc     => 'DC1',
    export => qw( $iws_rollout_phase );


use Test::More;
use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use XTracker::Config::Local qw( config_var );
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;
use Carp::Always;

test_prefix("Setup");
# Start-up gubbins here. Test plan follows later in the code...
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::WMS',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Fulfilment/Picking',
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Selection'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);

my $how_many_pids = 5;
# my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => $how_many_pids });
# my %products = map {; "P$_" => shift( @$pids ) } 1..$how_many_pids;
my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 5, phys_vouchers => { how_many => 2,want_stock => 3} });
# 5 regular products, 2 vouchers
my %products = map {; "P$_" => shift( @$pids ) } 1..7;

my %shipments;
# Create an order of products excluding a regular PID P5 and a voucher P7
# We will want these two to be dealt with as Orphans
for my $s ( 1 ) {
    $shipments{"S$s"} = $framework->flow_db__fulfilment__create_order(
        channel  => $channel,
        products => [ @products{qw/P1 P2 P3 P4 P6/} ],
    );
}
# Pack all of these in to tote T1
# Get a tote T2 which will be used for the Orphan items

 # We're going to throw an extra strayed item (P5) in T2 too

my %totes;
my $count;
# Create 2 totes. T!
for my $tote_id ( Test::XT::Data::Container->get_unique_ids( { how_many => 2 } )) {
    $totes{"T" . ++$count} = $tote_id;
}

if ($iws_rollout_phase > 0) {
    # Fake a ShipmentReady from IWS
    $framework->flow_wms__send_shipment_ready(
        shipment_id => $shipments{'S1'}->{'shipment_id'},
        container => {
            $totes{'T1'} => [ map { $_->{'sku'} } @products{qw/P1 P2 P3 P4 P6/} ]
        },
    );
}


# Let's place some extraneous items in a container
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $totes{'T1'} )
    ->flow_mech__fulfilment__packing_emptytote_submit('no');

like($framework->mech->app_info_message,
     qr{Please scan unexpected item},
     'packer asked to send shipment to exception desk');


# We should now be at the PIPE-O page
test_prefix("Packing PIPE-O");
$framework
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($products{'P1'}->{'sku'});

# PIPE-O'ing 2/3 canceled items
# We're leaving one cancelled item in the tote on purpose
$framework
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($totes{'T2'})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($products{'P2'}->{'sku'})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($totes{'T2'});

my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

# Mark process as done
# and mark the tote as emtpy
$framework
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_mark_complete
    ->flow_mech__fulfilment__packing_emptytote_submit('yes');


my $schema = Test::XTracker::Data->get_schema;
my $peo_tote_orphan_item_count = $schema->resultset('Public::OrphanItem')
    ->search({
        container_id => { -in => [ $totes{'T2'} ] },
    })->count;

is($peo_tote_orphan_item_count,2,"Right number of strayed skus in the tote");

$xt_to_wms->expect_messages({
    messages => [
        {
            '@type'   => 'route_tote',
            'details' => { container_id => $totes{'T2'},
                           destination  => 'packing exception'
                       },
        }],
});

done_testing;
