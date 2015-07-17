#!/opt/xt/xt-perl/bin/perl 

use strict;
use warnings;
use Carp;
use Test::More qw( no_plan );

use lib '/opt/xt/deploy/xtracker/lib/';
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( read_handle fcp_handle );

# compare stock levels of each db

open my $lfh, '>', '../logs/markdown.log' || die "can't open log file: $!";
print $lfh "[ sku ]\tfcp\txt\n";

my $dbh_x = read_handle();
my $dbh_f = fcp_handle();

my %markdown_x = ();

# xtracker markdowns
my $qry_x = q{ select product_id, ( percentage::int * -1 ) as percentage, date_start
               from price_adjustment where exported = 't'
             };

my $sth_x = $dbh_x->prepare( $qry_x );
$sth_x->execute();
my $results_x = $sth_x->fetchall_arrayref( {} );

# fcp markdowns
my $qry_f = q{ select sku, percentage, start_date, end_date
               from price_adjustment
             };
my $sth_f = $dbh_f->prepare( $qry_f );
$sth_f->execute();
my $results_f = $sth_f->fetchall_arrayref( {} );


# build hash for markdown comparison
foreach my $row_x ( @$results_x ){
    $markdown_x{ $row_x->{product_id} } = { percentage => $row_x->{percentage},
                                            start_date => $row_x->{start_date},
                                       };
}

# check each fcp level against xt level
foreach my $row_f ( @$results_f ){

    my $sku          = $row_f->{sku};
    my $percentage_f = $row_f->{percentage};
    my $start_date   = $row_f->{start_date};

    my ($product_id) = $sku =~ m/^(\d+)-.*$/xms;

    unless( ok( $percentage_f == $markdown_x{$product_id}->{percentage} , "[ $sku ] $percentage_f == $markdown_x{$product_id}->{percentage}" ) ){
        print $lfh "[ $sku ]\t$percentage_f\t$markdown_x{ $product_id }->{percentage}\n";
   }
}

close $lfh;
$dbh_x->disconnect();
$dbh_f->disconnect();
