#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;

use Test::XTracker::Data;

;
use Test::Exception;
use Data::Dump      qw( pp );


=head2

These tests will test various actions you can do on a 'Variant' from a DBIx point of view

Currently it tests:
    Schema::ResultSet::Public::Variant->find_by_sku()
    Schema::Result::Public::Variant->get_measurements()

(please add to above list as more things are tested)

=cut


my $schema  = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Sanity check: got Schema connection");

my $tmp;
my $prod_rs;
my $var_rs  = $schema->resultset('Public::Variant');

# get a product
my ( $channel, $pids )  = Test::XTracker::Data->grab_products();
note "Using SKU: ".$pids->[0]->{sku};

dies_ok( sub {
    $tmp = $var_rs->find_by_sku( '123456' );
}, "Invalid SKU format passed, dies" );

dies_ok( sub {
    $tmp = $var_rs->find_by_sku( '321-485' );
}, "Non-Existent SKU to search on, dies" );

lives_ok( sub {
    $tmp = $var_rs->find_by_sku( $pids->[0]{sku} );
}, "Proper SKU to search on, lives" );
isa_ok( $tmp, 'XTracker::Schema::Result::Public::Variant', "Returned a Variant" );
cmp_ok( $tmp->id, '==', $pids->[0]{variant_id}, "Found correct Variant Id" );

# test using an alias for when searching a resultset joined to variants
$prod_rs= $schema->resultset('Public::Product')->search( {}, { join => 'variants' } );
$tmp    = XTracker::Schema::ResultSet::Public::Variant::find_by_sku( $prod_rs, $pids->[0]{sku}, 'variants' );
isa_ok( $tmp, 'XTracker::Schema::Result::Public::Product', "Returned a Product using Alias" );
cmp_ok( $tmp->id, '==', $pids->[0]{pid}, "Found Variant's Product using Alias" );

dies_ok( sub {
    $tmp = XTracker::Schema::ResultSet::Public::Variant::find_by_sku( $prod_rs, '321-485', 'variants' );
}, "Non-Existent SKU to search on with Alias, dies" );

# testing asking not die if no sku is found
lives_ok( sub {
    $tmp = $var_rs->find_by_sku( '321-485', undef, 1 );
}, "Non-Existent SKU to search on, doesn't die when asked not to" );
ok( !defined $tmp, "Returned 'undef'" );

# testing asking not die if no sku is found with Alias
lives_ok( sub {
    $tmp = XTracker::Schema::ResultSet::Public::Variant::find_by_sku( $prod_rs, '321-485', 'variants', 1 );
}, "Non-Existent SKU to search on, doesn't die when asked not to and with Alias" );
    my $var = $var_rs->find( $pids->[0]{variant_id} );
ok( !defined $tmp, "Returned 'undef'" );

# test get_measurements
{

    my ($ignore, @pids) = Test::XTracker::Data->grab_products({how_many => 1, channel => 'nap', how_many_variants => 0 });
    #my $var = $var_rs->find( $pids->[0]{variant_id} );

    my $var_rs  = $schema->resultset('Public::Variant');
    my $var_meas_rs  = $schema->resultset('Public::VariantMeasurement');
    my $meas_rs  = $schema->resultset('Public::Measurement');
    # no idea why I cannot reference these values in the create as normal
    # this is horrible but i have no time
    my $width_id= $meas_rs->find({ measurement => 'Width' })->id;
    my $height_id= $meas_rs->find({ measurement => 'Height' })->id;
    my $length_id= $meas_rs->find({ measurement => 'Length' })->id;
    my $depth_id= $meas_rs->find({ measurement => 'Depth' })->id;
    my $variant = $var_rs->create({
        id => Test::XTracker::Data->next_id( [ qw( voucher.variant variant ) ] ),
        product_id => $pids->[0]{pid},
        size_id => 1,
        type_id => 1,
    });

    my $variant_id = $variant->id;

    $var_meas_rs->create( { variant_id => $variant_id, measurement_id => $width_id, value => 50 } );
    $var_meas_rs->create( { variant_id => $variant_id, measurement_id => $height_id, value => 300} );
    $var_meas_rs->create( { variant_id => $variant_id, measurement_id => $length_id, value => 999 } );
    $var_meas_rs->create( { variant_id => $variant_id, measurement_id => $depth_id, value => 237.66 } );

    is_deeply( $variant->get_measurements, { Width => 50 , Height => 300 , Length => 999 , Depth => 237.66} , 'get_measurements behaving as expected');

    note "remove all Variant Measurements for the Variant";
    $variant->discard_changes->variant_measurements->delete;
    isa_ok( $variant->get_measurements(), 'HASH', "'get_measurements' still returns a HASH Ref even when there are no measurements" );
    ok( !exists( $variant->get_measurements->{'Length'} ), "Found no 'Length' measrument now" );
}

done_testing();
