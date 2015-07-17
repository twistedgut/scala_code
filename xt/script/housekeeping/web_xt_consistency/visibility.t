#!/opt/xt/xt-perl/bin/perl 

use strict;
use warnings;
use Carp;
use Test::More qw( no_plan );

use lib '/opt/xt/deploy/xtracker/lib/';
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( read_handle fcp_handle );

# compare visibility

open my $lfh, '>', 'visibility.log' || die "can't open log file: $!";
print $lfh "[ product ]\t[ fcp ]\t[ xt ]\n";

my $dbh_x = read_handle();
my $dbh_f = fcp_handle();

my %visibility_x = ();

# xtracker sales tax rate
my $qry_x = q{ select id, CASE WHEN visible THEN 't' ELSE 'f' end as is_visible from product };

my $sth_x = $dbh_x->prepare( $qry_x );
$sth_x->execute();
my $results_x = $sth_x->fetchall_arrayref( {} );

# fcp sales tax rate
my $qry_f = q{ select id, lower(is_visible) as is_visible from searchable_product };
my $sth_f = $dbh_f->prepare( $qry_f );
$sth_f->execute();
my $results_f = $sth_f->fetchall_arrayref( {} );


# build hash for stock comparison
foreach my $row_x ( @$results_x ){
    $visibility_x{ $row_x->{id} } = $row_x->{is_visible};
}

# check each fcp level against xt level
foreach my $row_f ( @$results_f ){

    my $product_id   = $row_f->{id};
    my $is_visible_f = $row_f->{is_visible};

    unless( ok( $is_visible_f eq $visibility_x{ $product_id } , "[ $product_id ] $is_visible_f : $visibility_x{$product_id}" ) ){
        print $lfh "[ $product_id ]\t$is_visible_f\t$visibility_x{ $product_id }\n";
   }
}

close $lfh;
$dbh_x->disconnect();
$dbh_f->disconnect();
