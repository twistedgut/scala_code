#!/usr/bin/env perl
package Test::XT::Apache::Locations;
use NAP::policy "tt", 'test';


use Path::Class 'file';

use FindBin::libs;
#use FindBin::libs qw( base=data nouse export=datadirs );
#use Data::Dump qw/pp/;
#pp @datadirs;


use_ok("Test::XTracker::Data");
use_ok("Apache::Admin::Config");

ok( exists( $ENV{XTDC_BASE_DIR} ), 'Project base dir env var set')
    or BAIL_OUT "XTDC_BASE_DIR not set in env";
ok( (-d $ENV{XTDC_BASE_DIR} ), 'Project base dir points to dir')
    or BAIL_OUT "XTDC_BASE_DIR does not exist: ".$ENV{XTDC_BASE_DIR};

my $lib_base = $ENV{XTDC_BASE_DIR}.'/lib/';
ok( -d $lib_base, 'lib/ dir exists' );

my $file = $ENV{XTDC_BASE_DIR}.'/conf/xt_location.conf';
ok -e $file, "xt_locations.conf exists" ;

my $cfg = Apache::Admin::Config->new($file);
isa_ok $cfg, 'Apache::Admin::Config', 'construct an Apache::Admin::Config';

BAIL_OUT $Apache::Admin::Config::ERROR
    if $Apache::Admin::Config::ERROR;

my @loc = $cfg->section(-name => 'Location');
cmp_ok @loc, ">", 100, "Locations in xt_location.conf";

for my $loc (@loc) {
    my $ph = $loc->directive(-name => "PerlHandler");
    if ($ph) {
        my @h = split /\s+/, $ph;
        (my $filename = $h[-1]) =~ s{::}{/}g;
        my $wanted = file($lib_base, "$filename.pm");
        ok $wanted->stat, "found file $wanted for location ". $loc->value;
    }
}

done_testing;
