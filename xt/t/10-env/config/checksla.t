#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 Tests for shipping_charge_class table settings

This test is for testing 'shipping_charge_class' table is set-up correctly

Originally done for CANDO-578.

=cut

use Data::Dump qw( pp );
use Data::Dumper;


use Test::XTracker::Data;

use_ok( 'XTracker::Constants::FromDB', qw(
                                        :shipping_charge_class
                                    ) );

use XTracker::Constants::FromDB qw( :shipping_charge_class );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', 'Schema sanity check' );

my $shipping_charge_class_rs = $schema->resultset('Public::ShippingChargeClass');

# expected data with value of upgrade column
my %expected_data = (
        'Same Day'   => undef,
        'Air'        => undef,
        'Ground'     => $SHIPPING_CHARGE_CLASS__AIR,
    );


note "Testing 'shipping_charge_class' table";


my %got_data = map {$_->class => $_->upgrade } $shipping_charge_class_rs->all;
is_deeply( \%got_data, \%expected_data, "shipping_charge_class table has Expected data");


done_testing;
