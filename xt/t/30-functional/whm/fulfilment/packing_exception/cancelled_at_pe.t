#!/usr/bin/env perl

=head1 NAME

cancelled_at_pe.t - Test cancelling items at packing

=head1 DESCRIPTION

We will create a ten-item shipment. At packing QC, it will transpire:

    P0: Missing
    P1: Missing
    P2: Missing
    P2: Faulty
    P3: Faulty
    P4: Faulty
    P5: Fine
    P6: Fine
    P7: Fine
    P8: Fine

And we will send this to PE. Once it arrives at PE, we will have Customer Care
cancel the first 9 items. The PE supervisor will then:

    P0: Missing - Mark as Found and Putaway
    P1: Missing - Mark as Found, but Faulty, and then Quarantine
    P2: Missing - Confirm missing
    P3: Faulty  - Mark as Fine and Putaway
    P4: Faulty  - Quarantine
    P5: Faulty  - Mark as missing
    P6: Fine    - Putaway
    P7: Fine    - Mark as Faulty, and then Quarantine
    P8: Fine    - Mark as missing

B<CANCEL-PENDING ITEMS WITH QC INFORMATION MUST SHOW THAT INFORMATION>. We
decide an item is in Faulty Cancel Pending state if it has QC information and
is marked at Cancel Pending.

Relating to: https://napdcea.onjira.com/browse/LIVE-67

=head2 TEST MANIFEST

Copied from the code:

    # Case       Action          Stock Type  From                       L  Test desc
    [ P0 => 0 => 'putaway'    => 'main'   => { "no" => "where"       }, 0, "Missing, claim to have found it"  ],
    [ P1 => 1 => 'quarantine' => 'faulty' => { "no" => "where"       }, 0, "Missing, mark as found but faulty"],
    [ P3 => 3 => 'putaway'    => 'main'   => { container_id => $tote }, 0, "Faulty, mark as fine and putaway" ],
    [ P4 => 4 => 'quarantine' => 'faulty' => { container_id => $tote }, 0, "Faulty, quarantine it"            ],
    [ P5 => 5 => 'missing'    => 'main'   => { container_id => $tote }, 1, "Faulty, mark as missing"          ],
    [ P6 => 6 => 'putaway'    => 'main'   => { container_id => $tote }, 0, "Putaway cancelled item"           ],
    [ P7 => 7 => 'quarantine' => 'faulty' => { container_id => $tote }, 0, "OK, mark as faulty and quarantine"],
    [ P8 => 8 => 'missing'    => 'main'   => { container_id => $tote }, 1, "OK, but mark as missing"          ],
    [ P2 => 2 => 'missing'    => 'main'   => { "no" => "where"       }, 1, "Missing, really missing"          ],

#TAGS fulfilment packing packingexception loops whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::RunCondition(
    export => ['$iws_rollout_phase', '$distribution_centre'],
);

use Storable qw/dclone/;


use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use Test::Differences;

use Test::XTracker::Artifacts::RAVNI;
use Test::XT::Data::Container;

use XTracker::Database::Stock;

# Start-up gubbins here. Test plan follows later in the code...
test_prefix("Setup: Framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
    ],
);
$framework->clear_sticky_pages;
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
    ]},
    dept => 'Customer Care'
});
my $operator = $framework->schema->resultset('Public::Operator')->find({
    'username' => $framework->mech->logged_in_as,
});
my $operator_username = $operator->name;
# newlines get removed by the time we see the html error
# no, I don't know why someone's name would have one in, but
# on dc2 at the moment it.god's name does.
$operator_username =~ s/\n/ /gs;

my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

# create and pick the order
test_prefix("Setup: Order Shipment");
my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 9 });
my $order_data = $framework->flow_db__fulfilment__create_order_picked(
    channel  => $channel, products => $pids, );
note "shipment $order_data->{'shipment_id'} created";
my $shipment_id = $order_data->{'shipment_id'};
my @p = $order_data->{shipment_object}->shipment_items->all;

my ($tote) = Test::XT::Data::Container->get_unique_ids({ how_many => 1 });

# Go to pack it
test_prefix("Setup: Shipment to PE");
$framework
    ->flow_mech__fulfilment__packing;

$framework->mech__fulfilment__set_packing_station( $channel->id );

$framework
    ->flow_mech__fulfilment__packing_submit( $order_data->{tote_id} )
    ->catch_error(
        qr/Please scan item\(s\) from shipment/,
        'Send to PE',
        flow_mech__fulfilment__packing_checkshipment_submit => (
            missing => [ map { $_->id } @p[0..2] ],
            fail => {
                # Faulty
                $p[3]->id => 'faulty: there is a birds nest inside this',
                $p[4]->id => 'faulty: i think something has eaten all the buttons on this maybe a moth',
                $p[5]->id => 'faulty: rabbit fur on this item has decayed'
            }
        )
    );

# Put them all in a PE tote

# Present items
for ( 3 .. 8 ) {
    $framework
        ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $p[$_]->get_sku )
        ->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $tote );
}
$framework->flow_mech__fulfilment__packing_placeinpetote_mark_complete;

# Cancel items 0-8
test_prefix('Setup: Cancelling Items');
$framework
    ->flow_mech__customercare__orderview( $order_data->{'order_object'}->id )
    ->flow_mech__customercare__order_view_cancel_order
    ->flow_mech__customercare__cancel_order_submit
    ->flow_mech__customercare__cancel_order_email_submit;

# Open it up in Packing Inception
test_prefix('First Look');
$framework
    ->flow_mech__fulfilment__packingexception
    ->flow_mech__fulfilment__packingexception_submit( $tote );

# Wait for the RAVNI messages to catch up
$xt_to_wms->expect_messages({
    messages => [
        #($iws_rollout_phase > 0 ? ({ '@type' => "shipment_request"  }) : ()),
        { '@type' => "shipment_received" },
        { '@type' => "shipment_reject"   },
        { '@type' => "shipment_cancel"   },
    ]
});
undef($xt_to_wms);

# What are we expecting?
my $common = sub {
    my $item = shift;
    return (
        "Shipment Item ID" => $item->id,
        "SKU"              => $item->get_sku,
        "Status"           => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
    );
};
my %spec = (
    $p[0]->id => {
        "Actions"   => "This item has been cancelled but is missing",
        "Container" => "",
        "QC"        => "Failure reason: \xABMarked as missing from ".$order_data->{tote_id}."\xBB Packer name: ".$operator_username,
        $common->( $p[0] )
    },
    $p[1]->id => {
        "Actions"   => "This item has been cancelled but is missing",
        "Container" => "",
        "QC"        => "Failure reason: \xABMarked as missing from ".$order_data->{tote_id}."\xBB Packer name: ".$operator_username,
        $common->( $p[1] )
    },
    $p[2]->id => {
        "Actions"   => "This item has been cancelled but is missing",
        "Container" => "",
        "QC"        => "Failure reason: \xABMarked as missing from ".$order_data->{tote_id}."\xBB Packer name: ".$operator_username,
        $common->( $p[2] )
    },
    $p[3]->id => {
        "Actions"   => "This item has been cancelled and should be quarantined",
        "Container" => $tote,
        "QC"        => "Failure reason: \xABfaulty: there is a birds nest inside this\xBB Packer name: ".$operator_username,
        $common->( $p[3] )
    },
    $p[4]->id => {
        "Actions"   => "This item has been cancelled and should be quarantined",
        "Container" => $tote,
        "QC"        => "Failure reason: \xABfaulty: i think something has eaten all the buttons on this maybe a moth\xBB Packer name: ".$operator_username,
        $common->( $p[4] )
    },
    $p[5]->id => {
        "Actions"   => "This item has been cancelled and should be quarantined",
        "Container" => $tote,
        "QC"        => "Failure reason: \xABfaulty: rabbit fur on this item has decayed\xBB Packer name: ".$operator_username,
        $common->( $p[5] )
    },
    ( map {
        $p[$_]->id => {
            "Actions"   => "This item has been cancelled and should be putaway",
            "Container" => $tote,
            "QC"        => "Ok",
            $common->( $p[$_] )
        },
    } 6 .. 8 )
);
my @cancelled = ();

check_spec("first open");

my ($putaway_tote) = Test::XT::Data::Container->get_unique_ids({ how_many => 1 });

for (
    # Case       Action          Stock Type  From                       L  Test desc
    [ P0 => 0 => 'putaway'    => 'main'   => { "no" => "where"       }, 0, "Missing, claim to have found it"  ],
    [ P1 => 1 => 'quarantine' => 'faulty' => { "no" => "where"       }, 0, "Missing, mark as found but faulty"],
    [ P3 => 3 => 'putaway'    => 'main'   => { container_id => $tote }, 0, "Faulty, mark as fine and putaway" ],
    [ P4 => 4 => 'quarantine' => 'faulty' => { container_id => $tote }, 0, "Faulty, quarantine it"            ],
    [ P5 => 5 => 'missing'    => 'main'   => { container_id => $tote }, 1, "Faulty, mark as missing"          ],
    [ P6 => 6 => 'putaway'    => 'main'   => { container_id => $tote }, 0, "Putaway cancelled item"           ],
    [ P7 => 7 => 'quarantine' => 'faulty' => { container_id => $tote }, 0, "OK, mark as faulty and quarantine"],
    [ P8 => 8 => 'missing'    => 'main'   => { container_id => $tote }, 1, "OK, but mark as missing"          ],
    [ P2 => 2 => 'missing'    => 'main'   => { "no" => "where"       }, 1, "Missing, really missing"          ],
) {
    my ( $test_case, $test_number, $method_atom, $stock_status, $from, $lost, $test_name ) = @$_;
    my $p = $p[ $test_number ];
    my $method = 'flow_mech__fulfilment__packingexception_shipment_item_mark_' . $method_atom;

    my $allocated_skus_before = XTracker::Database::Stock::get_allocated_item_quantity(
        $framework->dbh, $p->get_product_id
    )->{ $channel->name }->{ $p->get_true_variant->id };

    test_prefix("$test_case: $test_name");
    $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    $framework->$method( $p->id );
    unless ( $method_atom eq 'missing' ) {
        $framework
        ->flow_mech__fulfilment__packing_scanoutpeitem_sku(  $p->get_sku );

        if($method_atom eq "putaway") {
            $framework->task__fulfilment__packing_scanoutpeitem_to_putaway(
                $putaway_tote,
                $p->get_sku,
            );
        }
        else {
            $framework->flow_mech__fulfilment__packing_scanoutpeitem_tote(
                $putaway_tote,
            );
        }
    }

    # It should now have disappeared from the screen
    delete $spec{ $p->id };
    # Set it to cancelled, unless it was PutAway in Phase 0
    push( @cancelled, $p->id ) unless $iws_rollout_phase == 0 && $method_atom eq 'putaway';
    check_spec("after $test_case $method_atom");

    # Should have an item moved
    if ( $iws_rollout_phase ) {
        $xt_to_wms->expect_messages({ messages => [ {
            'type'        => "item_moved",
            'details'     => {
                "shipment_id" => "s-$shipment_id",
                "from"        => $from,
                "to"          => {
                    ($lost ? ( place => 'lost' ) : (container_id => $putaway_tote)),
                    stock_status => $stock_status
                },
                "items"       => [{ quantity => 1, sku => $p->get_sku }]
            }
        } ] });
    }
    # If we *don't* have IWS we send an item_moved message to RAVNI - these are
    # ignored, so it let's ignore any messages sent at this point. It'd be nice
    # to ignore item_moved messages only, but the API doesn't have a way of
    # doing that at the moment
    else {
        $xt_to_wms->new_files;
    }

    my $allocated_skus_after = XTracker::Database::Stock::get_allocated_item_quantity(
        $framework->dbh, $p->get_product_id
    )->{ $channel->name }->{ $p->get_true_variant->id } || 0;

    my $allocation_decrease =
        ($iws_rollout_phase == 0 && $method_atom eq 'putaway') ? 0 : 1;

    is(
        $allocated_skus_after,
        ($allocated_skus_before - $allocation_decrease),
        "Allocated stock has decreased by 1"
    );
}

done_testing();


sub check_spec {
    my $msg = shift;

    my @web_fields = ('Actions', 'Container', 'QC', 'Shipment Item ID', 'SKU');

    # Grab and massage data from the website
    my $web_site_data = {
        map {
            my $item = $_;
            $item->{'Shipment Item ID'} => { map { $_ => $item->{$_} } @web_fields }
        } @{$framework->mech->as_data->{'shipment_items'}}
    };

    # Grab and massage data from our spec hash - remove any keys that aren't
    # in the web_fields from a copy of it.
    my $web_spec_data = dclone \%spec;
    for my $spec_item (values %$web_spec_data) {
        for my $spec_item_key (keys %$spec_item) {
            delete $spec_item->{$spec_item_key} unless
                grep { $_ eq $spec_item_key } @web_fields;
        }
    }

    # Compare the web-based data
    is_deeply( $web_site_data, $web_spec_data, "PE Screen items as expected at " . $msg );

    # Compare the shipment_item_status_id's
    my $type_spec = {
        map { $_->{'Shipment Item ID'} => $_->{'Status'} }
        values %spec
    };
    $type_spec->{ $_ } = $SHIPMENT_ITEM_STATUS__CANCELLED for @cancelled;

    my $type_site = {
        map { $_->id, $_->shipment_item_status_id }
        map { $framework->schema->resultset('Public::ShipmentItem')->find( $_ ) }
        (keys %spec, @cancelled)
    };

    eq_or_diff( $type_site, $type_spec, "Shipment Item Statuses as expected at " . $msg );
}

