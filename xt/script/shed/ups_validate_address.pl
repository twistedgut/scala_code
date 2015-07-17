#!/usr/bin/perl

use strict;
use warnings;
use Data::Dump  qw( pp );

use Net::UPS;
use Net::UPS::Address;

my $ups     = Net::UPS->new( 'nap_dc2ca_live', 'Toosh9GieR', 'FCEDDED86DDDF68' );
$ups->live(1);
my $address = Net::UPS::Address->new();

print $ups->access_as_xml()."\n";

$address->city("Long Island City");
$address->state("NY");
$address->postal_code("11101");
$address->country_code("US");

pp($address);

my $result  = $ups->validate_address( $address );

print $ups->errstr()."\n"       if ( defined $ups->errstr() );
my $counter = 0;
foreach ( @{ $result } ) {
    $counter++;
    print "Addr. ".$counter.": ".$_->quality."\n";
    pp($_);
}

