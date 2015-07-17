#!/usr/bin/env perl
# vim: set ts=4 sw=4 sts=4:

=head1 NAME

10-edit-po-change-number.t - XT API call to update purchase order number

=head1 DESCRIPTION

XT API call to update purchase order number.
Tests 400 bad request and 200 success errors.

=cut

use NAP::policy 'test';

use Test::XTracker::Data;
use Test::XT::DC::Mechanize;

use XTracker::Constants::FromDB qw( :channel );
use vars qw( $CHANNEL__NAP_INTL );

use JSON;

my $schema = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

my $products = Test::XTracker::Data->find_or_create_products(
    { channel_id => $CHANNEL__NAP_INTL, how_many => 1, skip_measurements=>1, force_create => 1 } );

my @pids = map { $_->{pid} } @{ $products };
my $po = Test::XTracker::Data->setup_purchase_order(
    \@pids,
);


isa_ok( $po, 'XTracker::Schema::Result::Public::PurchaseOrder', 'check type' );

my $old_po_number = $po->purchase_order_number;
my $new_po_number = 'NEWPONUMBER' . $old_po_number;

my $payload = {
    purchase_order_number => $new_po_number,
};

my $mech    = Test::XT::DC::Mechanize->new;
$mech->add_header(Accept => 'application/json');

subtest 'Succesfull response - 200' => sub {

    $mech->put_ok("/api/purchase-orders/$old_po_number",
        {content => encode_json($payload) });

    ok($mech->status, 'Request processed: 200');

    my $purchase_order = $schema->resultset('Public::PurchaseOrder')
        ->search({ purchase_order_number => $new_po_number })->single;

    is($purchase_order->purchase_order_number, $new_po_number,
        'Purchase order updated in DB: 200');
};

subtest 'Bad response - 400' => sub {

    $mech->put("/api/purchase-orders/$new_po_number",
        {content => encode_json($payload) });

    ok($mech->status, 'Request processed: 400');

    my $purchase_order = $schema->resultset('Public::PurchaseOrder')
        ->search({ purchase_order_number => $new_po_number })->single;

    is($purchase_order->purchase_order_number, $new_po_number,
        'Purchase order not updated in DB: 400');
};

done_testing();
