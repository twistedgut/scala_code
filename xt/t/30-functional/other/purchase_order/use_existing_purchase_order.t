#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

use_existing_purchase_order.t

=head1 DESCRIPTION

Create a purchase order

Set the operator's department to I<Buying> and give it manager-level
permissions to Stock Control/Purchase Order.

Go to /StockControl/PurchaseOrder/Orderview for the purchase order.

Click on Re-Order.

Submit the form with a startdate of now and a cancel ship date of next week,
with a quantity of 1.

Verify that we get a re-order successfully created message.

Go back to the PO's re-order page, and repeat the same submit. Check we get the
same success message.

#TAGS purchaseorder

=cut

use DateTime;
use Data::Dump  qw(pp);

use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/../../lib";
use lib "$Bin/../../../lib";

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Constants::FromDB qw/
    :purchase_order_status
    :stock_order_status
/;

my $mech = Test::XTracker::Mechanize->new;
my $schema = Test::XTracker::Data->get_schema;
my $dbh = $schema->storage->dbh;

my $channels= $schema->resultset('Public::Channel')->get_channels();
my $pid_list  = map { $_->{pid} } @{ (Test::XTracker::Data->grab_products({
    channel_id   => (keys %$channels)[0],
    force_create => 1, # true
}))[1] };

my $po = Test::XTracker::Data->setup_purchase_order( $pid_list );
# Mark everything delivered, in order to get the 'Re-Order' link
$po->update({ status_id => $PURCHASE_ORDER_STATUS__DELIVERED });
$po->stock_orders->first->update({ status_id => $STOCK_ORDER_STATUS__DELIVERED });

# Make the PO editable
$schema->resultset('Public::PurchaseOrderNotEditableInFulcrum')->create({
    number => $po->purchase_order_number
});
$po->discard_changes; # reload from DB
is($po->is_editable_in_xt,1,"Purchase Order is editable");

$mech->do_login;

Test::XTracker::Data->set_department('it.god', 'Buying');
Test::XTracker::Data->grant_permissions('it.god', 'Stock Control', 'Purchase Order', 3);

my $start_date = DateTime->now(time_zone => 'local')->strftime('%Y-%m-%d %H:%m');
my $cancel_date = DateTime->now(time_zone => 'local')->add( weeks => 1 )->strftime('%Y-%m-%d %H:%m');

note("Re-ordering first time");
submit_reorder($po->id, $start_date, $cancel_date);

$mech->has_feedback_success_ok('Re-Order successfully created','Re-Order successfully created');

note("Re-ordering second time");

# Warning: This assumes no other purchase orders have been created in-between:
my $next_po_id = $po->id + 1;
submit_reorder($next_po_id, $start_date, $cancel_date);

$mech->has_feedback_success_ok('Re-Order successfully created','Re-Order successfully added to');


sub submit_reorder {
    my ($po_id, $start_date, $cancel_date) = @_;

    $mech->get_ok('/StockControl/PurchaseOrder/Overview?po_id=' .  $po->id );
    $mech->follow_link_ok( { text => 'Re-Order' } );

    note("Selecting 'reorder' form");
    $mech->form_name("create_reorder");

    my ($first_quantity_input) = grep { $_->name =~ /^quantity_/ } $mech->current_form->inputs;
    note("Setting quantity in field '".$first_quantity_input->name."'");

    $mech->submit_form_ok({
        with_fields => {
            po_number => $po_id,
            start_ship_date => $start_date,
            cancel_ship_date => $cancel_date,
            $first_quantity_input->name  => 1,
        },
    }, "Added to existing PO \#$po_id");

}

done_testing();
