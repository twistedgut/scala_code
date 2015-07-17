#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

shipment_changes_in_pipe.t - Shipment changes during "Put In Packing Exception"

=head1 DESCRIPTION

Load up a shipment with 3 items. Pick, and place it on hold. Start to pack,
which takes us to PIPE page. While on the PIPE page, cancel an item.

#TAGS fulfilment packing packingexception cancel whm

=cut

use Test::XTracker::Data qw/qc_fail_string/;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use Test::XT::Data::Container;

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

# Rustle up 3 products
my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 3 });
my %products = map {; "P$_" => $pids->[($_-1)] } 1..(scalar @$pids);

# Knock up a tote
my ($tote_id, $packing_tote_id) =
    Test::XT::Data::Container->get_unique_ids( { how_many => 2 } );

# Create an order
my $product_data =
    $framework->flow_db__fulfilment__create_order_selected( channel => $channel, products => $pids );
my $shipment_id = $product_data->{'shipment_id'};
my $order_id    = $product_data->{order_object}->id;

# Pick it
$framework->task__picking($product_data->{shipment_object});
$framework->flow_msg__prl__induct_shipment(
    shipment_row => $product_data->{shipment_object},
);

# All picked. Let's put it on hold...
$framework
    ->flow_mech__customercare__orderview( $order_id )
    ->flow_mech__customercare__hold_shipment()
    ->flow_mech__customercare__hold_shipment_submit();

# Now try and pack it
$framework
    ->flow_mech__fulfilment__packing
    ->catch_error(
        qr/The shipment \d+ is on hold/,
        "Shipment marked as on hold",
        flow_mech__fulfilment__packing_submit => ( $tote_id )
    );

# Pipe page!
$framework
    ->test_mech__pipe_page__test_items(
        handled => [],
        pending => [ map {
            my $product = $products{"P$_"};
            {
                SKU => $product->{'sku'},
                QC  => 'Ok',
                Container => $tote_id
            }
        } 1..3 ]
    );

# Cancel an item from the shipment
$framework
    ->open_tab("Customer Care")
    ->flow_mech__customercare__orderview( $order_id )
    ->flow_mech__customercare__cancel_shipment_item()
    ->flow_mech__customercare__cancel_item_submit(
        [ $products{'P1'}->{'sku'} ]
    )->flow_mech__customercare__cancel_item_email_submit
    ->close_tab();

# Finish packing it on the PIPE page
for my $pid ( map {"P$_"} 1..3 ) {
    $framework->flow_mech__fulfilment__packing_placeinpetote_scan_item( $products{$pid}->{'sku'} );
    $framework->flow_mech__fulfilment__packing_placeinpetote_scan_item( $packing_tote_id );
}

# Check the PIPE page is done
$framework
    ->test_mech__pipe_page__test_items(
        pending => [],
        handled => [ map {
            my $product = $products{"P$_"};
            {
                SKU => $product->{'sku'},
                QC  => 'Ok',
                Container => $packing_tote_id
            }
        } 1..3 ]
    );

$framework->flow_mech__fulfilment__packing_placeinpetote_mark_complete();
done_testing();
