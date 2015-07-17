#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

bad_totes.t - Test for error when trying to use a tote containing an orphan item

=head1 DESCRIPTION

Create a shipment with three products in the I<Picked> state.

Begin packing the shipment.

Fail an item at packing QC and expect an error telling the user to send it to
packing exception.

Create an orphan item (directly in the db) for one of the items (move it from
its container to an orphan one).

Scan an item into a PE tote, scan a second item, then scan a container and
expect an error: "... being used for Superfluous Items ...".

Verify that the successfully moved item appears in the table on the page.

#TAGS fulfilment packing packingexception whm

=cut

use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(:authorisation_level
                                   :shipment_item_status
                                   :container_status
                              );
use XTracker::Database qw(:common);
use Test::XT::Data::Container;
use Carp::Always;
use Data::Dump 'pp';
use XTracker::Config::Local qw(config_var);

test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::PipePage',
        'Test::XT::Flow::Fulfilment',
    ],
);
$framework->clear_sticky_pages;
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Picking',
        'Fulfilment/Selection'
    ]},
    dept => 'Distribution'
});
$framework->mech->force_datalite(1);

test_prefix("Setup: order shipment");

my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 3,
});
my $order_data = $framework->flow_db__fulfilment__create_order_picked(
    channel  => $channel,
    products => $pids,
);

test_prefix("Setup: pack shipment");

$framework->mech__fulfilment__set_packing_station( $channel->id );
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $order_data->{tote_id} );

test_prefix("Setup: QC fail");

my @items = @{$framework->mech->as_data()->{shipment_items}};

$framework->catch_error(
    qr{send to the packing exception desk},
    'qc fail',
    flow_mech__fulfilment__packing_checkshipment_submit =>
        fail => {
            $items[0]->{shipment_item_id} => 'foo',
        },
);

my ($petote,$peotote) = Test::XT::Data::Container->get_unique_ids( { how_many => 2 } );

$framework->schema->resultset('Public::OrphanItem')->create_orphan_item(
    $pids->[2]{sku},
    $peotote,
    $order_data->{tote_id},
    $APPLICATION_OPERATOR_ID,
);

$framework
    ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $pids->[0]{sku} )
    ->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $petote )
    ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $pids->[1]{sku} )
    ->catch_error(
        qr{being used for Superfluous Items},
        'bad container',
        flow_mech__fulfilment__packing_placeinpetote_scan_tote => $peotote
    );

my $moved=$framework->mech->as_data()->{items_handled};

ok(defined($moved),'something is shown');
cmp_ok(scalar @{$moved},'==',1,'1 item');
cmp_ok($moved->[0]{SKU},'eq',$pids->[0]{sku},'right item');

done_testing();
