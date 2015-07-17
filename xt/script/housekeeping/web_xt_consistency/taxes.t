#!/opt/xt/xt-perl/bin/perl 

use strict;
use warnings;
use Carp;
use Test::More qw( no_plan );

use lib '/opt/xt/deploy/xtracker/lib/';
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( read_handle fcp_handle );

# compare stock levels of each db

open my $lfh, '>', '../logs/tax_rate.log' || die "can't open log file: $!";
print $lfh "[ sku ]\t[ fcp ]\t[ xt ]\n";

my $dbh_x = read_handle();
my $dbh_f = fcp_handle();

my %tax_rate_x = ();

# xtracker sales tax rate
my $qry_x = q{ select upper(c.code) as country, ( ctr.rate * 100 ) as rate
               from country c, country_tax_rate ctr
               where ctr.country_id = c.id
             };

my $sth_x = $dbh_x->prepare( $qry_x );
$sth_x->execute();
my $results_x = $sth_x->fetchall_arrayref( {} );

# fcp sales tax rate
my $qry_f = q{ select iso, vat_percentage from country_lookup where vat_percentage > 0 };
my $sth_f = $dbh_f->prepare( $qry_f );
$sth_f->execute();
my $results_f = $sth_f->fetchall_arrayref( {} );


# build hash for stock comparison
foreach my $row_x ( @$results_x ){
    $tax_rate_x{ $row_x->{country} } = $row_x->{rate};
}

# check each fcp level against xt level
foreach my $row_f ( @$results_f ){

    my $country = $row_f->{iso};
    my $rate_f  = $row_f->{vat_percentage};
    
    unless( ok( $rate_f == $tax_rate_x{$country} , "[ $country ] $rate_f : $tax_rate_x{$country}" ) ){
        print $lfh "[ $country ]\t$rate_f\t$tax_rate_x{ $country }\n";
   }
}
        

close $lfh;
$dbh_x->disconnect();
$dbh_f->disconnect();
