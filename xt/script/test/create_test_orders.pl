#!/usr/bin/env perl

=pod

=head1 Description

Script written primarily for testers, providing a quick and dirty way of generating an order in XTracker for testing

=head1 Synopsis

./t/script/create_test_order.pl -n 3 -c DHL -s picked

=head1 Limitations

* Only creates orders paid for via store credit so will not allow testing of PSP pre-auth verification.

=head1 Future enhancements

* Add ability to define valid/invalid shipment address

=cut

use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use NAP::policy "tt";
use Test::XT::Flow;
use Test::MockObject;
use Getopt::Long;
use XTracker::Constants::FromDB qw/:storage_type/;

my %opt = (
    products => 1,
);
my $result = GetOptions( \%opt,
    'state|s=s',
    'products|n=i',
    'carrier|c=s',
    'premier|p',
    'dematic|n=i',
    'multi|m',
);

my $allowed_suffix = {
    selected    => '_selected',
    picked      => '_picked',
    packed      => '_packed',
};
my $state = delete $opt{'state'};
die "Not a recognised suffix" if ($state && !$allowed_suffix->{$state});
my $suffix = ($state && $allowed_suffix->{$state}) ? $allowed_suffix->{$state} : '';

my $allowed_carrier = {
    'DHL Ground' => 1,
};
die "Not a recognised carrier" if ($opt{'carrier'} && !$allowed_carrier->{$opt{'carrier'}});


my $method = 'flow_db__fulfilment__create_order' . $suffix;

my $mockmech = Test::MockObject->new();
$mockmech->set_isa('Test::XTracker::Mechanize');
my $framework = Test::XT::Flow->new_with_traits(
    mech => $mockmech,
    traits => [
        'Test::XT::Flow::Fulfilment',
    ],
);

if (my $no_of_dematic = delete $opt{'dematic'}) {
    my $total_products = delete $opt{'products'};
    die 'Can not be more dematic products than total products'
        if $no_of_dematic > $total_products;
    my @products = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT,
        how_many => $no_of_dematic,
    });
    if ($total_products-$no_of_dematic) {
        my @non_dematic_products = Test::XTracker::Data->create_test_products({
            how_many => $total_products-$no_of_dematic,
        });
        @products = (@products, @non_dematic_products);
    }
    $opt{'products'} = \@products;
}

my $order_data = $framework->$method( %opt );
print "shipment $order_data->{'shipment_id'} created";
