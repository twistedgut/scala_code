#!/usr/bin/env perl

=head1 NAME

amend_incomplete_single.t - Change the size for an incomplete shipment item

=head1 DESCRIPTION

Testing that amending a shipment due to an incomplete pick properly sends the
correct messages to INVAR once all the incomplete items have been resolved,
either through size changes or through cancelling an item.

=head1 PURPOSE

To ensure that the process of altering the selected size for items that are
missing at pick by altering them to a size that is in stock properly sends the
correct XT_IN_03 message.

=head1 METHOD

This test is for the change-size-of-missing-item case. See
L<amend_incomplete_cancel.t> for the cancel-a-missing-item case.

Change Size Case:

=over

=item Create a new order for an item that has more than one size option.

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

Use the customer care screens to adjust the order, selecting a different size
for the incomplete item.

Make sure that:

=over

=item a shipment_request message was sent to INVAR for the shipment change

=item that request contains an additional item for the new SKU

=back

#TAGS picking incompletepick orderview changeitemsize fulfilment iws checkruncondition setupselection whm

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
# use Test::XT::Data::Tote;
use Test::Differences;

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
        'Customer Care/Customer Search',
    ]}
});
$framework->force_datalite(1);

my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
my $wms_to_xt = Test::XTracker::Artifacts::RAVNI->new('wms_to_xt');

my $schema = Test::XTracker::Data->get_schema;
my $channel = Test::XTracker::Data->get_local_channel;

# Create the order with products
my $product_count = 42;
my $product_data;
my $shipment_id;

if ($iws_rollout_phase == 0) {
    $product_data = $framework->flow_db__fulfilment__create_order( products => $product_count);
    $shipment_id = $product_data->{shipment_id};
    $framework
        ->flow_mech__fulfilment__selection
        ->flow_mech__fulfilment__selection_submit( $shipment_id )
    # promptly declare that the pick is incomplete
        ->flow_mech__fulfilment__picking
        ->flow_mech__fulfilment__picking_submit( $shipment_id )
        ->flow_mech__fulfilment__picking_incompletepick();

} else {
    my (undef,$pids) =
        Test::XTracker::Data->grab_products({
            ensure_stock_all_variants => 1,
            how_many => $product_count,
            channel => $channel,
        });

    # Create the order with 42 products
    $product_data = $framework->flow_db__fulfilment__create_order_selected(
        channel  => $channel,
        products => $pids,
    );

    $shipment_id = $product_data->{shipment_id};

    $framework->flow_wms__send_incomplete_pick(
        shipment_id => $shipment_id,
        operator_id => $APPLICATION_OPERATOR_ID,
        items       => [ map { $_->{sku} } @{ $product_data->{'product_objects'} } ],
    );
}


# we expect three messages to have appeared as a result of
# what we've done:
#
# + shipment_request  (created at fulfilment selection, sent to INVAR)
# + picking_commenced (sent to XT) -> only in phase 0
# + incomplete_pick   (sent to XT)
#

my $shipment_id_str="s-$shipment_id";

my @xt_messages = {
    'type'    => 'incomplete_pick',
    'details' => { shipment_id => $shipment_id_str }
};
if ($iws_rollout_phase == 0) {
    # make sure that a shipment request message got sent to INVAR
    my ($original_shipment_request)=$xt_to_wms->expect_messages( {
            messages => [ { 'type'   => 'shipment_request',
                            'details' => {
                                shipment_id => $shipment_id_str,
                                priority_class => $product_data->{shipment_object}->iws_priority_class
                            }
                          } ]
    } );
    push @xt_messages, {
        'type'    => 'picking_commenced',
        'details' => { shipment_id => $shipment_id_str }
    };
}

# make sure that an incomplete_pick message got sent to XT
$wms_to_xt->expect_messages( {
        messages => \@xt_messages,
} );

$framework->without_datalite(
    flow_mech__customercare__orderview => ( $product_data->{order_object}->id )
);

is( $framework->mech->as_data->{meta_data}->{'Shipment Hold'}->{'Reason'},
    'Incomplete Pick', "Order is on hold for Shipment Pick" );


note "Now changing the size of the first item";

$framework->flow_mech__customercare__size_change;

my $pre_change_form=$framework->mech->as_data;

my ($changing_item_index,$changing_item)=(undef,undef);

# hunt for the first item that has actual alternatives...
ITEM:
foreach my $item (0..scalar(@{$pre_change_form->{size_change_form}->{select_items}})) {
    if (    exists  $pre_change_form->{size_change_form}->{select_items}->[$item]->{change_to}
        &&  exists  $pre_change_form->{size_change_form}->{select_items}->[$item]->{change_to}->{values}
        && scalar(@{$pre_change_form->{size_change_form}->{select_items}->[$item]->{change_to}->{values}})>1) {
        note "Size change list: ".scalar(@{$pre_change_form->{size_change_form}->{select_items}->[$item]->{change_to}->{values}});
        $changing_item_index=$item;
        $changing_item=$pre_change_form->{size_change_form}->{select_items}->[$item];
        last ITEM;
    }
}

ok(defined($changing_item),"Will be changing item $changing_item_index");

# just change the first item to have the first alternative size
# (which will change the SKU for the affected line item)

my $old_sku=$changing_item->{SKU};
my ($new_sku,$new_sku_index)=(undef,undef);

SKU:
foreach my $sku (0..scalar(@{$changing_item->{change_to}->{values}})) {
   my $candidate_sku=$changing_item->{change_to}->{values}->[$sku]->{value};
   # actually, only part of that needs to be compared...
   $candidate_sku=~s/.*_(\d+-\d{3,4})$/$1/;

   if ($old_sku ne $candidate_sku) {
      $new_sku_index=$sku;
      $new_sku=$changing_item->{change_to}->{values}->[$sku]->{value};
      last SKU;
   }
}

ok(defined($new_sku),"Different SKU in position $new_sku_index");

# Actual SKU will be last component of that value:
$new_sku=~s/.*_(\d+-\d{3,4})$/$1/;

my $sku_count=scalar(grep { $_->{sku} eq $new_sku } @{ $product_data->{'product_objects'} } );

note "Original count for New SKU [$new_sku]: $sku_count";

isnt( $old_sku, $new_sku, "Old SKU and new SKU are different (self-check)" );
note "Will be changing SKU [$old_sku] to [$new_sku]";

$framework->flow_mech__customercare__size_change_submit(
    [ $old_sku => $new_sku ]
)->flow_mech__customercare__size_change_email_submit();

note "Check that the size change stuck";

$framework->flow_mech__customercare__orderview( $product_data->{order_object}->id )
    ->flow_mech__customercare__size_change;

my $post_change_form=$framework->mech->as_data;

# we now ought to have a cancelled item for the old SKU,
# and new item for the new one.


# first, look for the cancelled item
my ($cancelled_item)=grep { $_->{SKU} eq $changing_item->{SKU} }
                        @{$post_change_form->{size_change_form}->{select_items}};
ok($cancelled_item->{select_item}='Cancelled', "Old SKU $old_sku has been cancelled");

# then look for the new item
my ($new_item)=grep { $_->{SKU} eq $new_sku }
                     @{$post_change_form->{size_change_form}->{select_items}};
ok(ref $new_item->{select_item} eq 'HASH', "New SKU $new_sku has appeared");


note "Now looking for the corresponding message to INVAR";

my ($shipment_change) = $xt_to_wms->expect_messages( {
        messages => [ { 'type'   => 'shipment_request',
                        'details' => { shipment_id => $shipment_id_str }
                      } ]
} );

# we expect one message to have appeared as a result of
# what we've done:
#
# + shipment_request  (created at size change, sent to INVAR)
#

# make sure that a shipment request message got sent

my $new_sku_count=scalar(grep { $_->{sku} eq $new_sku } @{$shipment_change->{payload_parsed}->{items}});

note "New SKU [$new_sku] count in new shipment message: $new_sku_count";

ok( $new_sku_count == $sku_count+1,
   "Found an extra new SKU $new_sku item in the shipment request message");

done_testing();
