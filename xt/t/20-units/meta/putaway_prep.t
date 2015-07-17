#!/usr/bin/perl

=head1 NAME

putaway_prep.t - tests for Test::XT::Data::PutawayPrep

=head1 DESCRIPTION

Test::XT::Data::PutawayPrep contains methods to use when setting up tests
for Putaway Prep.

This file contains tests for those methods.

=cut

use NAP::policy "tt", 'test', 'class';
use FindBin::libs;
BEGIN { extends 'NAP::Test::Class' };

use Test::XTracker::RunCondition
    prl_phase=> 'prl';


use Test::XT::Data::PutawayPrep;
use XTracker::Database::PutawayPrep::RecodeBased;

sub stock_process_group : Tests {
    my ($test) = @_;

    my $test_setup = Test::XT::Data::PutawayPrep->new;

    my ($stock_process, $product_data)
        = $test_setup->create_product_and_stock_process(1);

    isa_ok( $stock_process, 'XTracker::Schema::Result::Public::StockProcess', 'stock process created' );

    isa_ok( $product_data->{product}, 'XTracker::Schema::Result::Public::Product', 'product created' );
    like( $product_data->{sku}, qr/^\d+\-\d+$/, 'sku created' );
    like( $product_data->{variant_id}, qr/^\d+$/, 'variant_id created' );

    like( $product_data->{pgid}, qr/^\d+$/, 'pgid created' );
}

sub stock_recode_group : Tests {
    my ($test) = @_;

    my $test_setup = Test::XT::Data::PutawayPrep->new;

    my ($stock_process, $product_data)
        = $test_setup->create_product_and_stock_process(1, { group_type => XTracker::Database::PutawayPrep::RecodeBased->name });

    isa_ok( $stock_process, 'XTracker::Schema::Result::Public::StockRecode', 'stock recode created' );

    isa_ok( $product_data->{product}, 'XTracker::Schema::Result::Public::Product', 'product created' );
    like( $product_data->{sku}, qr/^\d+\-\d+$/, 'sku created' );
    like( $product_data->{variant_id}, qr/^\d+$/, 'variant_id created' );

    like( $product_data->{recode_id}, qr/^\d+$/, 'return_id created' );
}

sub stock_return_group : Tests {
    my ($test) = @_;

    my $test_setup = Test::XT::Data::PutawayPrep->new;

    my ($stock_process, $product_data)
        = $test_setup->create_product_and_stock_process(1, { return => 1 });

    isa_ok( $stock_process, 'XTracker::Schema::Result::Public::StockProcess', 'stock process created' );

    isa_ok( $product_data->{product}, 'XTracker::Schema::Result::Public::Product', 'product created' );
    like( $product_data->{sku}, qr/^\d+\-\d+$/, 'sku created' );
    like( $product_data->{variant_id}, qr/^\d+$/, 'variant_id created' );

    like( $product_data->{pgid}, qr/^\d+$/, 'pgid created' );
    like( $product_data->{return_id}, qr/^\d+$/, 'return_id created' );
}

Test::Class->runtests;
