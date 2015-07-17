#!/usr/bin/env perl

=head1 NAME

incomplete_pick_msg.t - Test the 'Incomplete Pick' message

=head1 DESCRIPTION

Create a selected order, and send an 'Incomplete Pick' message.

Verify shipment is on hold for reason 'Incomplete Pick', verify the comment
says: "The following items were missing", and "The expected SKUs are present",
and verify that no other SKUs are present.

#TAGS fulfilment picking iws whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::Differences;
use Test::XT::Flow;
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw( :authorisation_level );
use XTracker::Database qw(:common);
use Test::XTracker::Artifacts::RAVNI;
use XTracker::Config::Local 'config_var';

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::Fulfilment',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search'
    ]}
});
my $schema = Test::XTracker::Data->get_schema;

# Create the order with five products
my $product_count = 5;
my $product_data =
    $framework->flow_db__fulfilment__create_order_selected(
        products => $product_count,
    );
my $shipment_id = $product_data->{'shipment_id'};

# Send the message
{
my $amq = Test::XTracker::MessageQueue->new();
my $receipt_directory = Test::XTracker::Artifacts::RAVNI->new('wms_to_xt');

$amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::IncompletePick', {
    operator_id => $APPLICATION_OPERATOR_ID,
    shipment_id => $shipment_id,
    items => [
        map { {
            sku      => $_->{'sku'},
            quantity => $_->{'num_ship_items'}
        } } @{ $product_data->{'product_objects'} }[0,1]
    ]
});
$receipt_directory->wait_for_new_files();
}

# Now there should be a note
$framework->flow_mech__customercare__orderview( $product_data->{'order_object'}->id );
my $shipment_hold = $framework->mech->as_data->{'meta_data'}->{'Shipment Hold'};
is( $shipment_hold->{'Reason'}, 'Incomplete Pick', "Incomplete Pick marked as reason" );
like( $shipment_hold->{'Comment'}, qr/The following items were missing/,
    "Incomplete Pick comment looks sane" );
my ( $sku1, $sku2, @others ) = $shipment_hold->{'Comment'} =~ m/(\d+-\d+)/g;
eq_or_diff(
    [ sort ($sku1, $sku2) ],
    [ sort map { $product_data->{'product_objects'}->[$_]->{'sku'} } 0..1 ],
    "The expected SKUs are present",
);
ok( (! @others), "No other SKUs are present" );

done_testing();
