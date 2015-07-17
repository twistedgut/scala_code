#!/usr/bin/env perl

use strict;
use warnings;

use FindBin::libs;

use Test::XTracker::Data;
use Test::Most;
use base 'Test::Class';

sub startup : Test(startup => 1) {
    use_ok 'XTracker::Schema::Result::Voucher::Product';
}

sub test_create_voucher : Tests {
    my $voucher = Test::XTracker::Data->create_voucher;
    isa_ok( $voucher, 'XTracker::Schema::Result::Voucher::Product' );
    my $schema = Test::XTracker::Data->get_schema;

    # voucher.variant -> voucher.product is a 1:1
    throws_ok {$schema->resultset('Voucher::Variant')->create({voucher_product_id=>$voucher->id})}
        qr/duplicate key value violates unique constraint/;

    my ($variant) = $voucher->variant;
    ok $variant->id;
    isa_ok( $variant, 'XTracker::Schema::Result::Voucher::Variant', 'check type');
    isa_ok( $variant->product, 'XTracker::Schema::Result::Voucher::Product', 'check type by variant' );

    # check cascade
    throws_ok  {$voucher->delete}  qr/update or delete on table "product" violates foreign key constraint/;
    ok($schema->resultset('Voucher::Variant')->find($variant->id)->delete, 'no variants should now exist');
    ok($voucher->delete);
}

Test::Class->runtests;
