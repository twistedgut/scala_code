#!/usr/bin/env perl

use strict;
use warnings;

use FindBin::libs;
use utf8;

use Test::XTracker::Data;
use Test::Most;

use XTracker::DBEncode qw( encode_it );

use base 'Test::Class';

sub startup : Test(startup => 3) {
    use_ok 'XTracker::Schema::Result::Public::Product';
    use_ok 'XTracker::Database::Product';
    use_ok 'XTracker::Schema';
}

sub test_check_product_simple_search : Tests {
    my $dbh = Test::XTracker::Data->get_dbh;

    my %args = ();
    is(
        XTracker::Database::Product::simple_product_search($dbh, \%args),
        undef,
        'searching with no args returns nothing'
    );
    %args = (
        discount    => "all",
        live        => "all",
        location    => "all",
        stockvendor => "all",
        visible     => "all",
    );

    my $voucher = Test::XTracker::Data->create_voucher;
    my %params = ( product_id => $voucher->id, keywords => $voucher->name );
    while ( my ($key, $val) = each %params ) {
        my $r = XTracker::Database::Product::simple_product_search(
            $dbh, { %args, $key => $val } );
        ok($r->[0]{id} == $voucher->id, "found voucher using $key");
    }

    my ( $product ) = Test::XTracker::Data->create_test_products();
    my $product_attributes = $product->product_attribute;

    my $unicode = {
        name                => '試驗',
        description         => "تجربة",
    };

    $product_attributes->update( { %{ $unicode } } );

    my $search_result = XTracker::Database::Product::simple_product_search(
        $dbh, { %args, product_id => $product->id } );

    ok ( $search_result, "I have a search result" );
    ok ( ref $search_result eq 'ARRAY', "search_result is an array ref" );
    ok ( scalar @$search_result == 1, "there is only 1 element" );
    ok ( ref $search_result->[0] eq 'HASH', "and that element is a hashref" );

    use Data::Printer; note p($search_result);

    foreach my $test ( keys %$unicode ) {
        note $test;
        ok( utf8::is_utf8( $search_result->[0]->{$test} ),
            "$test data in search result is recognised as UTF-8" );
        is( $unicode->{$test}, $search_result->[0]->{$test}, encode_it($test)." values are the same" );
    }

}

Test::Class->runtests;
