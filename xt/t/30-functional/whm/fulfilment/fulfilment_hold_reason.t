#!/usr/bin/env perl

=head1 NAME

fulfilment_hold_reason.t - Test hold reason changes

=head1 DESCRIPTION

Tests to support the change that the hold reason will be incorporated into an
XT_IN_16 message, when the shipment is put on hold. This tests only runs under
IWS.

=head2 PURPOSE

Make sure that the shipment pause message, sent to INVAR when the shipment is
put on-hold, contains the reason for the hold as set in XT.

=head2 METHOD

=head3 Part One: set up the test

Create a test order
Pick it

=head3 Part Two: provoke the expected message

Go to 'Customer Care -> Order View'
Click 'Hold Shipment' in the left-hand nav
Provide the Hold reason (automatically set to 'Other')

=head3 Part Three: check the message appeared

Find the message
Check that it refers to the right shipment ID
Check that it contains the correct status (true)
Check that it contains the reason

#TAGS iws holdshipment fulfilment setuppicking setupselection whm

=head1 SEE ALSO

http://jira.nap/browse/DCEA-844

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

# This test is all about the shipment_wms_pause message, which is only important
# when we're running with IWS.
use Test::XTracker::RunCondition iws_phase => 'iws', export => qw( $iws_rollout_phase );


use Test::XTracker::Data qw/qc_fail_string/;
use Test::XT::Flow;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use Test::XT::Data::Container;
use JSON::XS;
use Test::XTracker::Artifacts::RAVNI;

# Start-up gubbins here. Test plan follows later in the code...
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::AppMessages',
        'Test::XT::Feature::PipePage',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::WMS',
    ],
);

note "Opening RAVNI message queue and prepping it for subsequent reading";

my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

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

# Part One...

# Load up a shipment with 3 items. Pick, and place it on hold. Start to pack,
# which takes us to PIPE page. While on the PIPE page, cancel an item.

# Rustle up 3 products
my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 3 });
my %products = map {; "P$_" => shift( @$pids ) } 1..(scalar @$pids);

# Create a shipment
my $shipment = $framework->flow_db__fulfilment__create_order(
    channel  => $channel,
    products => [ map { $products{"P$_"} } 1..3 ],
);

my $shipment_id = $shipment->{'shipment_id'};

my $order_id = $shipment->{'order_object'}->id;

# Knock up a tote
my ($tote_id, $packing_tote_id) =
    Test::XT::Data::Container->get_unique_ids( { how_many => 2 } );

my $shipment_id_str="s-$shipment_id";

note "Picking shipment $shipment_id from order $order_id";

if ($iws_rollout_phase == 0) {

    # Select the order, and start the picking process
    my $picking_sheet =
        $framework->flow_task__fulfilment__select_shipment_return_printdoc( $shipment_id );

    $framework
        ->flow_mech__fulfilment__picking
        ->flow_mech__fulfilment__picking_submit( $shipment_id );

    # Pick the items according to the pick-sheet
    for my $item (@{ $picking_sheet->{'item_list'} }) {
        my $location = $item->{'Location'};
        my $sku      = $item->{'SKU'};

        $framework->flow_mech__fulfilment__picking_pickshipment_submit_location( $location );
        $framework->flow_mech__fulfilment__picking_pickshipment_submit_sku( $sku );
        $framework->flow_mech__fulfilment__picking_pickshipment_submit_container( $tote_id );
    }

} else { # phase > 0

    $framework->flow_mech__fulfilment__selection
        ->flow_mech__fulfilment__selection_submit($shipment_id);

    # Fake a ShipmentReady from IWS
    $framework->flow_wms__send_shipment_ready(
        shipment_id => $shipment_id,
        container => {
            $tote_id => [ map { $products{"P$_"}->{'sku'} } 1..3 ]
        },
    );

}

note "Looking for one new WMS message";
$xt_to_wms->expect_messages( {
        messages => [ { 'type'   => 'shipment_request',
                        'details' => { shipment_id => $shipment_id_str }
                      },
                    ]
} );

# Part Two...
#
# All picked. Let's put it on hold...
$framework
    ->flow_mech__customercare__orderview( $order_id )
    ->flow_mech__customercare__hold_shipment()
    ->flow_mech__customercare__hold_shipment_submit();

$framework->flow_mech__customercare__orderview( $order_id );
is( $framework->mech->as_data->{meta_data}->{'Shipment Hold'}->{'Reason'},
    'Other', "Order is on hold for reason 'Other'" );

# the hold_shipment_submit() method automatically
# makes the reason 'Other'

# Part Three...
#
# Check that the shipment pause message appeared,
# that the shipment is paused, and that the reason
# has been passed through

note "Looking for one new message";
$xt_to_wms->expect_messages( {
        messages => [ { 'type'    => 'shipment_wms_pause',
                        'details' => { shipment_id => $shipment_id_str,
                                       pause       => JSON::XS::true,
                                       reason      => 'Other',
                                     }
                      }
                    ]
} );

done_testing();
