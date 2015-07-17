#!/usr/bin/env perl

=head1 NAME

fulfilment_offhold.t - Test taking a shipment off hold

=head1 DESCRIPTION

Tests to support the change that a supervisor taking a shipment off hold spits
out an XT_IN_16 message.

=head2 PURPOSE

Make sure that the above-mentioned change actually emits a message to INVAR,
containing the change in shipment status to 'off-hold', once a shipment,
current on-hold for incomplete pick, is taken off hold.

=head2 METHOD

=head3 Part One: set up the test

Create a test order
Start picking it
Mark the shipment as 'incomplete pick'

=head3 Part Two: provoke the expected message

Go to 'Fulfilment -> On Hold'
Click on the link for the shipment (from the 'Incomplete Pick' section)
Click 'Hold Shipment' in the left-hand nav
Something

=head3 Part Three: check the message appeared

Find the message
Check that it refers to the right shipment ID
Check that it contains the correct status

#TAGS iws fulfilment picking holdshipment checkruncondition whm

=head1 SEE ALSO

See http://jira.nap/browse/DCEA-552

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XT::Flow;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw( :authorisation_level );
use XTracker::Database qw(:common);
use Test::XTracker::Data;
use Test::XT::Data::Container;
use Test::Differences;
use JSON::XS;
use Test::XTracker::Artifacts::RAVNI;

use Test::XTracker::RunCondition dc => 'DC1', export => qw( $iws_rollout_phase );

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::WMS',
    ],
);
$framework->login_with_permissions({
    dept => 'Distribution Management',
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Picking',
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Selection',
        'Fulfilment/On Hold',
        'Customer Care/Customer Search',
    ]}
});

my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
my $wms_to_xt = Test::XTracker::Artifacts::RAVNI->new('wms_to_xt');

note "Creating test order with arbitrary product";
my $schema = Test::XTracker::Data->get_schema;

# Create the order with one product
my $product_data = $framework->flow_db__fulfilment__create_order( products => 1 );
my $shipment_id = $product_data->{shipment_id};

# Select the order and trigger shipment_request message
$framework->flow_mech__fulfilment__selection
    ->flow_mech__fulfilment__selection_submit($shipment_id);

my $shipment_id_str="s-$shipment_id";

if ($iws_rollout_phase == 0) {
    note "Declaring the pick as incomplete";
    $framework
        ->flow_mech__fulfilment__picking
        ->flow_mech__fulfilment__picking_submit( $shipment_id )
        ->flow_mech__fulfilment__picking_incompletepick();

    # we expect three messages to have appeared as a result of
    # what we've done:
    #
    # + shipment_request  (created at fulfilment selection, sent to INVAR)
    # + picking_commenced (sent to XT)
    # + incomplete_pick   (sent to XT)
    #

    my $shipment_id_str="s-$shipment_id";

    note "Looking for one new RAVNI message";
    $xt_to_wms->expect_messages( {
            messages => [ { 'type'   => 'shipment_request',
                            'details' => { shipment_id => $shipment_id_str }
                          } ]
    } );

    note "Looking for two new XT messages";
    $wms_to_xt->expect_messages( {
            messages => [ { 'type'    => 'picking_commenced',
                            'details' => { shipment_id => $shipment_id_str }
                          },
                          { 'type'    => 'incomplete_pick',
                            'details' => { shipment_id => $shipment_id_str }
                          }
                        ]
    } );
} else {

    # we expect two messages to have appeared as a result of
    # what we've done:
    #
    # + shipment_request  (created at fulfilment selection, sent to INVAR)
    # + incomplete_pick   (sent to XT)
    #

    note "Looking for one new IWS message";
    $xt_to_wms->expect_messages( {
            messages => [ { 'type'   => 'shipment_request',
                            'details' => { shipment_id => $shipment_id_str }
                          } ]
    } );

    # Send incomplete pick message to XT
    $framework->flow_wms__send_incomplete_pick(
        shipment_id => $shipment_id,
        operator_id => $APPLICATION_OPERATOR_ID,
        items       => [ map { $_->{sku} } @{ $product_data->{'product_objects'} } ],
    );


    note "Looking for one new XT message";
    $wms_to_xt->expect_messages( {
            messages => [ { 'type'    => 'incomplete_pick',
                            'details' => { shipment_id => $shipment_id_str }
                          }
                        ]
    } );
}


$framework->flow_mech__customercare__orderview( $product_data->{order_object}->id );
is( $framework->mech->as_data->{meta_data}->{'Shipment Hold'}->{'Reason'},
    'Incomplete Pick', "Order is on hold for Shipment Pick" );


# Part Two...
note "Taking the shipment off hold";

$framework->flow_mech__fulfilment__on_hold
    ->flow_mech__fulfilment__on_hold__select_incomplete_pick_shipment( $shipment_id )
    ->flow_mech__fulfilment__on_hold__hold_shipment
    ->flow_mech__fulfilment__on_hold__release_shipment
    ->flow_mech__customercare__orderview( $product_data->{order_object}->id );

is( $framework->mech->as_data->{meta_data}->{'Shipment Hold'}->{'Reason'},
    undef, "Order is off hold for Shipment Pick" );


# Part Three...
note "Checking that the 'shipment_wms_pause' message popped out";

# we expect one message to have appeared as a result of
# what we've done:
#
# + shipment_wms_pause  (created at off-hold, sent to INVAR)
#

# make sure that a shipment status change message got sent
$xt_to_wms->expect_messages( {
        messages => [ { 'type'   => 'shipment_wms_pause',
                        'details' => { shipment_id => $shipment_id_str,
                                       pause      => JSON::XS::false }
                      } ]
} );

done_testing();
