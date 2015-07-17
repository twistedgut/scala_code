#!/opt/xt/xt-perl/bin/perl 

use strict;
use warnings;
use Carp;
use Test::More qw( no_plan );

use lib '/opt/xt/deploy/xtracker/lib/';
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( read_handle fcp_handle );

# compare stock levels of each db

open my $lfh, '>', '../logs/currency.log' || die "can't open log file: $!";
print $lfh "[ conversion ]\t[ fcp ]\t[ xt ]\n";

my $dbh_x = read_handle();
my $dbh_f = fcp_handle();

my %conversion_x = ();

# xtracker currency
my $qry_x = q{ select c1.currency as source, c2.currency as dest, scr.conversion_rate, scr.date_start
               from sales_conversion_rate scr, currency c1, currency c2
               where scr.source_currency    = c1.id
               and scr.destination_currency = c2.id
               and date_start = ( select max(date_start) from sales_conversion_rate )
             };

my $sth_x = $dbh_x->prepare( $qry_x );
$sth_x->execute();
my $results_x = $sth_x->fetchall_arrayref( {} );

# fcp currency
my $qry_f = q{ select source_code, destination_code, rate, last_updated_dts from currency_rate };
my $sth_f = $dbh_f->prepare( $qry_f );
$sth_f->execute();
my $results_f = $sth_f->fetchall_arrayref( {} );


# build hash for comparison
foreach my $row_x ( @$results_x ){
    my $key = $row_x->{source} . '-' . $row_x->{dest};
    $conversion_x{ $key } = $row_x->{conversion_rate};
}

# check each fcp level against xt level
foreach my $row_f ( @$results_f ){

    my $key  = $row_f->{source_code} . '-' . $row_f->{destination_code};;
    my $rate_f = $row_f->{rate};
    
    unless( ok( $rate_f == $conversion_x{$key} , "[ $key ] $rate_f : $conversion_x{$key}" ) ){
        print $lfh "[ $key ]\t$rate_f\t$conversion_x{$key}\n";
   }
}
        

close $lfh;
$dbh_x->disconnect();
$dbh_f->disconnect();
