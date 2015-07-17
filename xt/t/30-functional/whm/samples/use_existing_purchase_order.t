#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

use_existing_purchase_order.t - Test we can add a sample request to an existing purchase order

=head1 DESCRIPTION

Create a Sample Purchase Order, add another sample to it.

#TAGS sample purchaseorder goodsin http duplication checkruncondition whm

=cut

use FindBin::libs;



use Test::XTracker::Data;
use Test::XTracker::Mechanize;

use Test::XTracker::RunCondition database => 'full', dc => 'DC1';

my $mech = Test::XTracker::Mechanize->new;
my $schema = Test::XTracker::Data->get_schema;
my $dbh = $schema->storage->dbh;

$mech->do_login;
Test::XTracker::Data->set_department('it.god', 'Sample');
Test::XTracker::Data->grant_permissions('it.god', 'Stock Control', 'Sample', 3);
Test::XTracker::Data->grant_permissions('it.god', 'Stock Control', 'Inventory', 3);

$mech->get_ok('/StockControl/Sample');
$mech->follow_link_ok({ text_regex => qr/\d{1,7}-\d{3}/ }, "SKU of pending stock request");
$mech->follow_link_ok({ url_regex => qr/StockControl\/Sample\/PurchaseOrder\?product_id=/ } ,'Sample Purchase Order');
my ($pid) = ($mech->uri =~ /product_id=(\d*)/ );
#get pid for later
{
    $mech->follow_link_ok({ text => 'create' }, "create");

    # get the po form
    my ($po_form) = grep { $_->attr('name') eq 'rock' } $mech->forms;

    my ($first_quantity_input) = grep { $_->name =~ /sample.*ord$/ } $po_form->inputs;

    $mech->submit_form_ok({
            with_fields => { $first_quantity_input->name  => 1, },
        }, 'Submit sample PO' );

    $mech->has_feedback_success_ok('Sample Purchase Order Created', 'Sample Purchase Order Created');
}

#now repeat the process to make sure we can add to the same purchase order
$mech->get_ok('/StockControl/Sample/PurchaseOrder?product_id=' . $pid , 'Got back to PO page');

{

    $mech->follow_link_ok({ text => 'create' }, "create");

    # get the po form
    my ($po_form) = grep { $_->attr('name') eq 'rock' } $mech->forms;
    my ($first_quantity_input) = grep { $_->name =~ /sample_.*ord$/ } $po_form->inputs;

    $mech->submit_form_ok({
            with_fields => { $first_quantity_input->name  => 1, },
        }, 'Added to existing PO' );

    $mech->has_feedback_success_ok('Sample Purchase Order Created', 'Existing Sample Purchase Order added to');
}

done_testing();
