#!/opt/xt/xt-perl/bin/perl 

use strict;
use warnings;
use Carp;
use Test::More qw( no_plan );

use lib '/opt/xt/deploy/xtracker/lib/';
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( read_handle fcp_handle );

# compare visibility

open my $lfh, '>', '../logs/live.log' || die "can't open log file: $!";
print $lfh "[ product ]\t[ fcp ]\t[ xt ]\n";

my $dbh_x = read_handle();
my $dbh_f = fcp_handle();

my %live_f = ();
my %live_x = ();

# xtracker live product
my $qry_x = q{ select id from product where live = 't' and season_id > 14 };

my $sth_x = $dbh_x->prepare( $qry_x );
$sth_x->execute();
my $results_x = $sth_x->fetchall_arrayref( {} );

# fcp live products
my $qry_f = q{ select id from searchable_product };
my $sth_f = $dbh_f->prepare( $qry_f );
$sth_f->execute();
my $results_f = $sth_f->fetchall_arrayref( {} );

# build hash for stock comparison
foreach my $row_f ( @$results_f ){
    $live_f{ $row_f->{id} } = 1;
}

# build hash for stock comparison
foreach my $row_x ( @$results_x ){
    $live_x{ $row_x->{id} } = 1;
}
# check each xt level against fcp level
foreach my $row_x ( @$results_x ){

    my $product_id = $row_x->{id};

    unless( ok( $live_f{ $product_id }, "[ $product_id ] xt live/fcp not" ) ){
        print $lfh "[ $product_id ]\tnot live\tlive\n";
   }
}

# check each fcp level against xt level
foreach my $row_f ( @$results_f ){

    my $product_id = $row_f->{id};

    unless( ok( $live_x{ $product_id }, "[ $product_id ] fcp live/xt not" ) ){
        print $lfh "[ $product_id ]\tlive\tnot live\n";
   }
}

close $lfh;
$dbh_x->disconnect();
$dbh_f->disconnect();
