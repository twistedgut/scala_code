#!/opt/xt/xt-perl/bin/perl 

use strict;
use warnings;
use Carp;
use Test::More qw( no_plan );
use Test::Harness::Straps;

use lib '/opt/xt/deploy/xtracker/lib/';
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( read_handle fcp_handle );



# compare stock levels of each db

my $strap = Test::Harness::Straps->new();

open my $lfh, '>', '../logs/country.log' || die "can't open log file: $!";
print $lfh "[ country ]\tfcp\n";

my $dbh_x = read_handle();
my $dbh_f = fcp_handle();

my %country_x = ();
my %country_f = ();


# xtracker stock level
my $qry_x = q{ select c.country, c.code, cu.currency
               from country c, currency cu
               where c.currency_id = cu.id};

my $sth_x = $dbh_x->prepare( $qry_x );
$sth_x->execute();
my $results_x = $sth_x->fetchall_arrayref( {} );

# fcp stock level
my $qry_f = q{ select display_name, iso, currency from country_lookup };
my $sth_f = $dbh_f->prepare( $qry_f );
$sth_f->execute();
my $results_f = $sth_f->fetchall_arrayref( {} );


# build hashes for country comparison
foreach my $row_x ( @$results_x ){
    $country_x{ $row_x->{code} } = { name     => $row_x->{country},
                                     currency => $row_x->{currency},
                                };
}

foreach my $row_f ( @$results_f ){
    $country_f{ $row_f->{iso} } = { name     => $row_f->{display_name},
                                    currency => $row_f->{currency},
                               };
}

# check each fcp level against xt level
foreach my $code_x ( keys %country_x ){

    unless( ok( exists $country_f{$code_x}, "[  $country_x{$code_x}->{name} ($code_x) ] Present" ) ){
        print $lfh "[ $country_x{$code_x}->{name} ($code_x) ]\tNot Present\n";
    }
    unless( ok( $country_x{$code_x}->{name} eq $country_f{$code_x}->{name} , "[ $country_x{$code_x}->{name} ] Name Match" ) ){
        print $lfh "[ $country_x{$code_x}->{name} ]\tName Mismatch\n";
    }
    unless( ok( $country_x{$code_x}->{currency} eq $country_f{$code_x}->{currency} , "[ $country_x{$code_x}->{name} ] Currency Match" ) ){
        print $lfh "[ $country_x{$code_x}->{name} ]\tCurrency Mismatch\n";
    }

}
    
close $lfh;
$dbh_x->disconnect();
$dbh_f->disconnect();
