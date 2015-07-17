#!/usr/bin/env perl

use NAP::policy qw/test/;

=head1 NAME

boxes_in_totes.t - Test packing into different boxes

=head1 DESCRIPTION

    Check shipment, pack shipment, for:

        * Small boxes
        * Premier
        * "Hide from IWS"

    Verify shipment_received and shipment_packed messages are sent.

#TAGS fulfilment packing iws checkruncondition whm

=cut

use FindBin::libs;


use Test::More::Prefix qw/test_prefix/;
use Test::XT::Flow;

use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_type);
use XTracker::Database qw(:common);

use Test::XTracker::Artifacts::RAVNI;
use Test::XT::Data::Container;
use Test::XTracker::RunCondition
    iws_phase => '2', export => qw( $iws_rollout_phase );

#use XTracker::Database::Stock;

# Start-up gubbins here. Test plan follows later in the code...
test_prefix("Setup: Framework");

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [ 'Fulfilment/Packing' ]},
    dept => 'Customer Care'
});
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

# Two shipments, both alike in dignity,
# In fair Charlton, where we lay our scene...
my %shipments = (
    small_boxes   => $framework->flow_db__fulfilment__create_order_picked(
        channel => 'nap', products => 3 ),
    sanity_check  => $framework->flow_db__fulfilment__create_order_picked(
        channel => 'nap', products => 2 ),
    premier       => $framework->flow_db__fulfilment__create_order_picked(
        channel => 'nap', products => 2 ),
    hide_from_iws => $framework->flow_db__fulfilment__create_order_picked(
        channel => 'nap', products => 2 )
);
$shipments{'premier'}->{'shipment_object'}->update({
    shipment_type_id => $SHIPMENT_TYPE__PREMIER });

my ( $premier_tote, @small_totes ) = Test::XT::Data::Container->get_unique_ids( { how_many => 3 } );

# SANITY CHECK
test_prefix("Sanity check");
{
    my $shipment_box = Test::XTracker::Data->get_next_shipment_box_id;
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $shipments{'sanity_check'}->{'tote_id'} )
        ->flow_mech__fulfilment__packing_checkshipment_submit();
    $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $_ )
        for map {$_->{'sku'} } @{ $shipments{'sanity_check'}->{'product_objects'} };

    # Submit box id's plus a container id
    $framework
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
            channel_id => $shipments{'sanity_check'}->{'channel_object'}->id,
            shipment_box_id => $shipment_box
        )->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789")
        ->flow_mech__fulfilment__packing_packshipment_complete;

    # Check the container id made it to the right place
    $xt_to_wms->expect_messages({
        messages => [
            { type => 'shipment_received' },
            {
                type => 'shipment_packed',
                details => { containers => [ $shipment_box ] }
            }
        ]
    });
}

# SMALL BOXES
test_prefix("Small Boxes");
{

    $framework->errors_are_fatal(0);

    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $shipments{'small_boxes'}->{'tote_id'} )
        ->flow_mech__fulfilment__packing_checkshipment_submit()
    # Pack one item
        ->flow_mech__fulfilment__packing_packshipment_submit_sku(
            $shipments{'small_boxes'}->{'product_objects'}->[0]->{'sku'}
    # Assign a small box
        )->flow_mech__fulfilment__packing_packshipment__assign_boxes
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
            channel_id => $shipments{'small_boxes'}->{'channel_object'}->id,
            tote_id    => $shipments{'small_boxes'}->{'tote_id'}
        );


    is($framework->mech->app_error_message,
         'You must use a new tote.', 'got correct error message');

    $framework->errors_are_fatal(1);
    $framework->flow_mech__fulfilment__packing_packshipment__pack_items
    # Pack one item
        ->flow_mech__fulfilment__packing_packshipment_submit_sku(
            $shipments{'small_boxes'}->{'product_objects'}->[1]->{'sku'}
    # Assign a small box
        )->flow_mech__fulfilment__packing_packshipment__assign_boxes
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
            channel_id => $shipments{'small_boxes'}->{'channel_object'}->id,
            tote_id    => $small_totes[0]
        )->flow_mech__fulfilment__packing_packshipment__pack_items
    # Pack the other item
        ->flow_mech__fulfilment__packing_packshipment_submit_sku(
            $shipments{'small_boxes'}->{'product_objects'}->[2]->{'sku'}
    # Assign a small box
        )->flow_mech__fulfilment__packing_packshipment_submit_boxes(
            channel_id => $shipments{'small_boxes'}->{'channel_object'}->id,
            tote_id    => $small_totes[1]
        )->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789")
        ->flow_mech__fulfilment__packing_packshipment_complete;

    # Check the container id made it to the right place
    $xt_to_wms->expect_messages({
        messages => [
            { type => 'shipment_received' },
            {
                type => 'shipment_packed',
                details => { containers => [ @small_totes ] }
            }
        ]
    });



}



# PREMIER
# Pack the items
test_prefix("Premier");
{
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $shipments{'premier'}->{'tote_id'} )
        ->flow_mech__fulfilment__packing_checkshipment_submit();
    $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $_ )
        for map {$_->{'sku'} } @{ $shipments{'premier'}->{'product_objects'} };

    # Submit box id's plus a container id
    $framework
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
            channel_id => $shipments{'premier'}->{'channel_object'}->id,
            tote_id    => $premier_tote
        )->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789")
        ->flow_mech__fulfilment__packing_packshipment_complete;

    # Check the container id made it to the right place
    $xt_to_wms->expect_messages({
        messages => [
            { type => 'shipment_received' },
            {
                type => 'shipment_packed',
                details => { containers => [ $premier_tote ] }
            }
        ]
    });
}

# Hide from IWS
# Pack the items
test_prefix("Hide from IWS");
{
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $shipments{'hide_from_iws'}->{'tote_id'} )
        ->flow_mech__fulfilment__packing_checkshipment_submit();
    $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $_ )
        for map {$_->{'sku'} } @{ $shipments{'hide_from_iws'}->{'product_objects'} };

    # Submit box id's plus a container id
    $framework
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
            channel_id    => $shipments{'premier'}->{'channel_object'}->id,
            tote_id       => $premier_tote,
            hide_from_iws => 1,
        )->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789")
        ->flow_mech__fulfilment__packing_packshipment_complete;

    # Check the container id made it to the right place
    $xt_to_wms->expect_messages({
        messages => [
            { type => 'shipment_received' },
            {
                type => 'shipment_packed',
                details => { containers => [] }
            }
        ]
    });
}


done_testing();
