#!/usr/bin/env perl

=head1 NAME

amend_incomplete_cancel.t - Cancel an incomplete pick

=head1 DESCRIPTION

Testing that amending a shipment due to an incomplete pick properly sends the
correct messages to INVAR once all the incomplete items have been resolved,
either through size changes or through cancelling an item.

=head1 PURPOSE

To ensure that the process of cancelling an item that is missing at pick
properly sends the correct XT_IN_03 message.


=head1 METHOD

This test is for the cancelling a missing item case. See
L<amend_incomplete_size.t> for the change-size item case.

=over

=item Create a new order for two items

=item Take that order to picking

=item Set the shipment to be 'Incomplete' because the item is not available

=item Check that the shipment is on hold.

=back

Make sure that:

=over

=item a shipment_request message was sent to INVAR for the shipment

=item a picking_started  message came from INVAR

=item an incomplete_pick message came from INVAR

=back

Use the customer care screens to adjust the order, cancelling an item

Make sure that:

=over

=item a shipment_request message was sent to INVAR for the shipment change

=back

#TAGS iws fulfilment picking incompletepick cancelitem checkruncondition setupselection whm

=head1 SEE ALSO

http://jira.nap/browse/DCEA-504

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XT::Flow;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw( :authorisation_level );
use XTracker::Database qw(:common);
use Test::XTracker::Data;
use Test::Differences;
use Test::XTracker::RunCondition
    prl_phase => 0,
    export => [qw( $iws_rollout_phase )];

use Test::XTracker::Artifacts::RAVNI;

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
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Picking',
        'Fulfilment/Selection',
        'Customer Care/Order Search',
        'Customer Care/Customer Search',
    ]}
});
$framework->force_datalite(1);

my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
my $wms_to_xt = $iws_rollout_phase ?
    Test::XTracker::Artifacts::RAVNI->new('wms_to_xt') :
    $framework->wms_receipt_dir;

# prep the queues for processing
(undef)=$xt_to_wms->new_files;
(undef)=$wms_to_xt->new_files;

my $schema = Test::XTracker::Data->get_schema;

my $method_name = $iws_rollout_phase ?
    'flow_db__fulfilment__create_order_selected' :
    'flow_db__fulfilment__create_order';


# Create the order with five products
my $product_data = $framework->$method_name( products => 5 );
my $shipment_id = $product_data->{shipment_id};
my $shipment_id_str="s-$shipment_id";

if ( $iws_rollout_phase == 0 ) {

    # Select the order, and start the picking process
    $framework
        ->flow_mech__fulfilment__selection
        ->flow_mech__fulfilment__selection_submit( $shipment_id )
    # promptly declare that the pick is incomplete
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

$xt_to_wms->expect_messages( {
        messages => [ { '@type'   => 'shipment_request',
                        'details' => { shipment_id => $shipment_id_str }
                      } ]
} );

} else {

    $framework->flow_wms__send_incomplete_pick(
        shipment_id => $shipment_id,
        operator_id => $APPLICATION_OPERATOR_ID,
        items       => [ map { $_->{sku} } @{ $product_data->{'product_objects'} } ],
    );

}

# make sure that a picking_commenced message got sent to XT (phase 0 only?)
# make sure that an incomplete_pick message got sent to XT
$wms_to_xt->expect_messages( {
        messages => [
                      $iws_rollout_phase == 0 ? (
                          { 'type'    => 'picking_commenced',
                            'details' => { shipment_id => $shipment_id_str }
                          },
                      ) : (),
                      { 'type'    => 'incomplete_pick',
                        'details' => { shipment_id => $shipment_id_str }
                      }
                    ]
} );

$framework->without_datalite(
    flow_mech__customercare__orderview => ( $product_data->{order_object}->id )
);

is( $framework->mech->as_data->{meta_data}->{'Shipment Hold'}->{'Reason'},
    'Incomplete Pick', "Order is on hold for Shipment Pick" );

note "Now cancelling the first item";

$framework->flow_mech__customercare__cancel_shipment_item;

my $pre_change_form=$framework->mech->as_data;

# just cancel the first item
my $first_item=$pre_change_form->{cancel_item_form}->{select_items}->[0];

my $pid=$first_item->{PID};
note "PID of cancelled item is $pid";
$framework
    ->flow_mech__customercare__cancel_item_submit( $pid )
    ->flow_mech__customercare__cancel_item_email_submit();

note "Check that the cancellation stuck";

$framework->flow_mech__customercare__orderview( $product_data->{order_object}->id )
    ->flow_mech__customercare__cancel_shipment_item;

my $post_change_form=$framework->mech->as_data;

# we now ought to have a cancelled item for the old PID

# look for the cancelled item
my ($cancelled_item)=grep {   exists  ($_->{PID})
                           && defined ($_->{PID})
                           && ($_->{PID} eq $first_item->{PID}) }
                        @{$post_change_form->{cancel_item_form}->{select_items}};
ok($cancelled_item->{select_item}='Cancelled', "PID $pid has been cancelled");

note "Now looking for the corresponding message to INVAR";

# we expect one message to have appeared as a result of
# what we've done:
#
# + shipment_request  (created at item cancellation, sent to INVAR)
#

$xt_to_wms->expect_messages( {
        messages => [ { 'type'   => 'shipment_request',
                        'path'    => $iws_rollout_phase ? $Test::XTracker::Data::iws_queue_regex : qr{/ravni_wms$},
                        'details' => { shipment_id => $shipment_id_str }
                      } ]
} );

done_testing();
