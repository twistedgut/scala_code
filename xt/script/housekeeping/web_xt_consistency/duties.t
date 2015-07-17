#!/opt/xt/xt-perl/bin/perl 

use strict;
use warnings;
use Carp;
use Test::More qw( no_plan );

use lib '/opt/xt/deploy/xtracker/lib/';
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( read_handle fcp_handle );

# compare stock levels of each db

open my $lfh, '>', '../logs/duty_rate.log' || die "can't open log file: $!";
print $lfh "[ duty ]\t[ fcp ]\t[ xt ]\n";

my $dbh_x = read_handle();
my $dbh_f = fcp_handle();

my %duties_x = ();

# xtracker duty rate
my $qry_x = q{ select upper(c.code) as country, hs.hs_code, ( cdr.rate * 100 ) as rate
               from country c, hs_code hs, country_duty_rate cdr
               where cdr.country_id = c.id
               and cdr.hs_code_id = hs.id
             };

my $sth_x = $dbh_x->prepare( $qry_x );
$sth_x->execute();
my $results_x = $sth_x->fetchall_arrayref( {} );

# fcp duty rate
my $qry_f = q{ select * from country_duties};
my $sth_f = $dbh_f->prepare( $qry_f );
$sth_f->execute();
my $results_f = $sth_f->fetchall_arrayref( {} );


# build hash for stock comparison
foreach my $row_x ( @$results_x ){
    $duties_x{ $row_x->{country} }->{ $row_x->{hs_code} } = $row_x->{rate};
}

# check each fcp level against xt level
foreach my $row_f ( @$results_f ){

    my $country = $row_f->{country};
    my $hs_code = $row_f->{hs_code};
    my $rate_f  = $row_f->{duty_percentage};

    unless( ok( $rate_f == $duties_x{$country}->{$hs_code} , "[ $country-$hs_code ] $rate_f : $duties_x{$country}->{$hs_code}" ) ){
        print $lfh "[ $country-$hs_code ]\t$rate_f\t$duties_x{$country}->{$hs_code}\n";
   }
}

close $lfh;
$dbh_x->disconnect();
$dbh_f->disconnect();
