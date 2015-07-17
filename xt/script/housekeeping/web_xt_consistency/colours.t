#!/opt/xt/xt-perl/bin/perl 

use strict;
use warnings;
use Carp;
use Test::More qw( no_plan );

use lib '/opt/xt/deploy/xtracker/lib/';
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( read_handle fcp_handle );

# compare stock levels of each db

open my $lfh, '>', 'colour.csv' || die "can't open log file: $!";
print $lfh "PID,xt,fcp\n";

my $dbh_x = read_handle();
my $dbh_f = fcp_handle();

my %colour_fcp = ();

# fcp colours
my $qry_f = q{ select search_prod_id, colour from product group by search_prod_id, colour };
my $sth_f = $dbh_f->prepare( $qry_f );
$sth_f->execute();
my $results_f = $sth_f->fetchall_arrayref( {} );

# build hash for colour comparison
foreach my $row_f ( @$results_f ){
    $colour_fcp{ $row_f->{search_prod_id} } = $row_f->{colour};
}



# xtracker colours
my $qry_x= q{ select p.id, cf.colour_filter as colour
                from product p, filter_colour_mapping fcm, colour_filter cf 
                where p.colour_id = fcm.colour_id 
                and fcm.filter_colour_id = cf.id 
                and p.live = true 
                and p.visible = true
                and p.season_id > 20
           };


my $sth_x = $dbh_x->prepare( $qry_x );
$sth_x->execute();
my $results_x = $sth_x->fetchall_arrayref( {} );

# check each fcp level against xt level
foreach my $row_x ( @$results_x ){

    my $prod_id  = $row_x->{id};
    my $colour_x = $row_x->{colour};
    
    unless( ok( $colour_x eq $colour_fcp{$prod_id} , "[ $prod_id ] $colour_x : $colour_fcp{$prod_id}" ) ){
        print $lfh "$prod_id,$colour_x,$colour_fcp{$prod_id}\n";
   }
}
        

close $lfh;

$dbh_x->disconnect();
$dbh_f->disconnect();
