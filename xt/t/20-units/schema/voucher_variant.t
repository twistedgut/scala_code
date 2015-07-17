#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;

use Test::XTracker::Data;

;
use Test::Exception;
use Data::Dump      qw( pp );


=head2

These tests will test various actions you can do on a 'Voucher::Variant' from a DBIx point of view

Currently it tests:
    Schema::ResultSet::Voucher::Variant->find_by_sku()

(please add to above list as more things are tested)

=cut


my $schema  = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Sanity check: got Schema connection");

my $tmp;
my $prod_rs;
my $var_rs  = $schema->resultset('Voucher::Variant');

$schema->txn_do( sub {

    # test for both Physical & Virtual Vouchers
    my %tests   = (
            'Physical'  => {
                voucher => Test::XTracker::Data->create_voucher( { is_physical => 1 } ),
            },
            'Virtual'   => {
                voucher => Test::XTracker::Data->create_voucher( { is_physical => 0 } ),
            },
        );

    my $unused_voucher_id
        = $var_rs->get_column("voucher_product_id")->max() + 1;

    foreach my $test ( sort keys %tests ) {

        my $voucher = $tests{ $test }{voucher};
        my $variant = $voucher->variant;

        note "Test using a $test Voucher";
        note "Voucher: ".$voucher->id.", SKU: ".$variant->sku;

        dies_ok( sub {
            $tmp = $var_rs->find_by_sku( '123456' );
        }, "Invalid SKU format passed, dies" );

        dies_ok( sub {
            $tmp = $var_rs->find_by_sku( "$unused_voucher_id-485" );
        }, "Non-Existent SKU to search on, dies" );

        lives_ok( sub {
            $tmp = $var_rs->find_by_sku( $voucher->variant->sku );
        }, "Proper SKU to search on, lives" );
        isa_ok( $tmp, 'XTracker::Schema::Result::Voucher::Variant', "Returned a Variant" );
        cmp_ok( $tmp->id, '==', $variant->id, "Found correct Variant Id" );

        # test using an alias for when searching a resultset joined to variants
        $prod_rs= $schema->resultset('Voucher::Product')->search( {}, { join => 'variant' } );
        $tmp    = XTracker::Schema::ResultSet::Voucher::Variant::find_by_sku( $prod_rs, $variant->sku, 'variant' );
        isa_ok( $tmp, 'XTracker::Schema::Result::Voucher::Product', "Returned a Voucher Product using Alias" );
        cmp_ok( $tmp->id, '==', $voucher->id, "Found Variant's Voucher Product using Alias" );

        dies_ok( sub {
            $tmp = XTracker::Schema::ResultSet::Voucher::Variant::find_by_sku( $prod_rs, "$unused_voucher_id-485", 'variant' );
        }, "Non-Existent SKU to search on with Alias, dies" );

        # testing asking not die if no sku is found
        lives_ok( sub {
            $tmp = $var_rs->find_by_sku( "$unused_voucher_id-485", undef, 1 );
        }, "Non-Existent SKU to search on, doesn't die when asked not to" );
        ok( !defined $tmp, "Returned 'undef'" );

        # testing asking not die if no sku is found with Alias
        lives_ok( sub {
            $tmp = XTracker::Schema::ResultSet::Voucher::Variant::find_by_sku( $prod_rs, "$unused_voucher_id-485", 'variant', 1 );
        }, "Non-Existent SKU to search on, doesn't die when asked not to and with Alias" );
        ok( !defined $tmp, "Returned 'undef'" );
    }

    # get rid of anything we've created
    $schema->txn_rollback();
} );

done_testing();

