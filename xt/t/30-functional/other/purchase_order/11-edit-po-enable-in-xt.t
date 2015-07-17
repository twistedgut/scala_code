#!/usr/bin/env perl

=head1 NAME

11-edit-po-enable-in-xt.t - test ability to turn edit po on in XT

=head1 DESCRIPTION

Create some products and setup a purchase order.

Send purchase order update to REST API for products created above.

Tests include:
    * Attempting to enable a purchase order in XT
    * Attempting to enable to same purchase order again in XT.

=cut

use NAP::policy "tt", 'test';

use FindBin::libs;

use JSON;

use Test::XTracker::Data;
use Test::XT::DC::Mechanize;
use Test::Differences;
my $json    = JSON->new;
my $mech    = Test::XT::DC::Mechanize->new;
$mech->add_header(Accept => 'application/json');

my $schema = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

# Create the products and purchase order.
my $po = _setup_products_and_po();

# Tests to make PO editable in XT.
_make_po_editable_in_xt( $mech, $po );

sub _setup_products_and_po {
    # Start transaction
    my $guard = $schema->storage->txn_scope_guard;

    my $products = Test::XTracker::Data->find_or_create_products( {
        how_many => 2, skip_measurements => 1, force_create => 1 } );

    my @pids = map { $_->{pid} } @{ $products };

    is (@pids, 2, "Expects 2 products to be found");

    note "Working with pids: ". p @pids;

    my $po = Test::XTracker::Data->setup_purchase_order(
        \@pids,
    );

    isa_ok( $po, 'XTracker::Schema::Result::Public::PurchaseOrder', 'check type' );

    note "Purchase order number is: ",$po->purchase_order_number;

    # Commit transaction
    $guard->commit;

    return $po;
}

sub _make_po_editable_in_xt {
    my ( $mech, $po ) = @_;

    # Mock data from fake fulcrum, data will be sent in the app from a REST client in Fulcrum.
    # Scenario: Enable editing of a PO in XT
    note "Enable editing of a PO in XT";
    # Username it.god wants to enable editing of a purchase order in XT.
    # Send enable editpo update via REST
    $mech->put_ok(
        '/api/purchase-orders/' . $po->purchase_order_number . '/enable-editpo-xt',
        { content => encode_json({ operator_username => 'it.god' }) }
    );

    # Should have a copy of the previous data in the db, in case we need to rollback
    my $previous_data_hash = decode_json $mech->content;

    # Checking rollback data exists
    eq_or_diff([keys %$previous_data_hash], ["previous_po_editable_status"],
        "Rollback data as expected" );

    # Now check the update via REST was successful
    my $enable_edit_po_in_xt = $po->is_not_editable_in_fulcrum;

    # Scenario: Try to enable a PO that is already enabled in XT
    note "Attempting to enable a PO that is already enabled in XT.";
    # Attempt to send same PO to be editable in XT.
    # We should notify user that PO is already editable in XT.
    # Send enable editpo update via REST
    $mech->put(
        '/api/purchase-orders/' . $po->purchase_order_number . '/enable-editpo-xt',
        content => encode_json( { operator_username => 'it.god' } )
    );

    ok( !$mech->success, 'PO is already editable in XT' );

    is($mech->status, 400, '400 bad request status returned');

    $mech->content_like(
        qr/EditPO api error: The purchase order is already editable in XT/,
        'Correct error message shown was PO is already editable in XT'
    );
}


done_testing;
