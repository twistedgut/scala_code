#!/usr/bin/env perl

=head1 NAME

stock_inventory.t - Basic tests for the Inventory page

=head1 DESCRIPTION

Create voucher, ensure it's displayed on the Inventory page.

Create product, ensure it's displayed on the Inventory page.

#TAGS inventory voucher whm

=cut

use strict;
use warnings;

use FindBin::libs;
use Test::XTracker::Data;
use Test::Most;
use Test::XTracker::Mechanize;
use Data::Dump qw/pp/;

use base 'Test::Class';

sub startup : Test(startup => 1) {
    use_ok 'XTracker::Database::Stock';
}

sub test_stock_inventory_page_for_voucher : Tests {
    ok(my $voucher = Test::XTracker::Data->create_voucher);
    Test::XTracker::Data->set_voucher_stock({variant_id=>$voucher->variant->id,quantity=>100,voucher=>$voucher});
    diag "voucher id :.".$voucher->id;

    Test::XTracker::Data->grant_permissions('it.god', 'Stock Control', 'Inventory', 1);

    my $mech = Test::XTracker::Mechanize->new;
    $mech->do_login;
    $mech->get_ok('/StockControl/Inventory/Overview?product_id='.$voucher->id);
    $mech->content_contains('Test Voucher '. $voucher->id);
}

sub test_stock_inventory_page_for_product : Tests {
    my $p = (Test::XTracker::Data->grab_products({how_many=>1}))[1]
        ->[0]{product_channel}
        ->product;

    Test::XTracker::Data->grant_permissions('it.god', 'Stock Control', 'Inventory', 1);

    my $mech = Test::XTracker::Mechanize->new;
    $mech->do_login;
    $mech->get_ok('/StockControl/Inventory/Overview?product_id='.$p->id);
}

Test::Class->runtests;
