#!/opt/xt/xt-perl/bin/perl -w
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib/";
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Database;

my $dbh = read_handle() || die print "Error: Unable to connect to DB";

my $last_quarter_start = '2008-04-01';
my $quarter_start = '2008-07-01';

### set up data sets
my %sales = ();
my %perc_sales = ();
my %category = ();
my %percentile = ();
my %age = ();
my %stock = ();
my %live = ();
my %counted = ();
my %date = ();
my %yearly_count = ();
my %sixmonth_count = ();
my $total_sales = 0;

## prepare insert statement for use later on
##############################
my $ins_qry = "insert into stock_count_variant values (?, ?, (select id from stock_count_category where category = ?), null)";
my $ins_sth = $dbh->prepare($ins_qry);

## get value of stock sold over last 3 months
#############################

my $qry = "select variant_id, sum(unit_price) from shipment_item where shipment_id in (select id from shipment where shipment_class_id = 1 and date between '$last_quarter_start' and '$quarter_start') group by variant_id";
my $sth = $dbh->prepare($qry);
$sth->execute();
while ( my $row = $sth->fetchrow_arrayref() ) {
        $sales{$row->[0]} = $row->[1];
        $total_sales += $row->[1];
}

## get all located stock
###############

$qry = "select v.id, q.location_id from variant v, quantity q where v.id = q.variant_id and q.location_id in (select id from location where type_id = 1 and location != 'GI') and q.quantity > 0";
$sth = $dbh->prepare($qry);
$sth->execute();
while ( my $row = $sth->fetchrow_arrayref() ) {
        $stock{$row->[0]}{$row->[1]} =  1;
}

## get last count dates
###############

$qry = "select variant_id, location_id, max(date) from stock_count where stock_count_status_id = 3 group by variant_id, location_id";
$sth = $dbh->prepare($qry);
$sth->execute();
while ( my $row = $sth->fetchrow_arrayref() ) {
        $date{$row->[0]}{$row->[1]} = $row->[2];
}

$qry = "select variant_id from stock_count where stock_count_status_id = 3 group by variant_id having max(date) > current_timestamp - interval '1 year'";
$sth = $dbh->prepare($qry);
$sth->execute();
while ( my $row = $sth->fetchrow_arrayref() ) {
        $yearly_count{$row->[0]} = 1;
}

$qry = "select variant_id from stock_count where stock_count_status_id = 3 group by variant_id having max(date) > current_timestamp - interval '6 months'";
$sth = $dbh->prepare($qry);
$sth->execute();
while ( my $row = $sth->fetchrow_arrayref() ) {
        $sixmonth_count{$row->[0]} = 1;
}

## get live stock
###########

$qry = "select v.id, to_char(u.upload_date, 'YYYYMMDD') from variant v, product p, upload_product up, upload u where v.product_id = p.id and p.live
 = true and p.id = up.product_id and up.upload_id = u.id and u.upload_date < '$quarter_start'";
$sth = $dbh->prepare($qry);
$sth->execute();
while ( my $row = $sth->fetchrow_arrayref() ) {
        if ($stock{$row->[0]}) {
                $live{$row->[0]} = $row->[1];
        }
}


## calculate sales percentiles for each variant
##############################

## 1 = top 80%, 2 = next 15%, 3 = next 5%

my $running_total = 0;

foreach my $var_id (sort hashValueDescendingNum (keys(%sales))) {

        $running_total += $sales{$var_id};

        if (($running_total / $total_sales) < 0.8 ) {
                $percentile{$var_id} = 1;
        }
        elsif (($running_total / $total_sales) < 0.95 ) {
                $percentile{$var_id} = 2;
        }
        else {
                $percentile{$var_id} = 3;
        }


}

my $num_b = 0;
my $num_c = 0;
my $num_d = 0;

### categorise each variant
foreach my $var_id ( keys (%stock) ) {

        ### only uploaded products are included
        if ($live{$var_id}) {

                my $cat;

                ## stock which has sales
                if ($percentile{$var_id}) {
                        ## top 80% of sales
                        if ($percentile{$var_id} == 1) {
                                $cat = "B";
                                $num_b++;
                        }
                        ## next 15% of sales
                        elsif ($percentile{$var_id} == 2) {
                                $cat = "C";
                                $num_c++;
                        }
                        ## last 5% of sales
                        else {
                                $cat = "D";
                                $num_d++;
                        }
                }
                ## no sales info
                else {
                        $cat = "D";
                        $num_d++;
                }

                $category{$var_id} = $cat;
        }
}

### now do the database inserts - we need to loop using upload date to work out oldest vars

my $c_loop = 1;
my $d_loop = 1;

my $totalB = 0;
my $totalC = 0;
my $totalD = 0;

foreach my $var_id (sort hashValueAscendingNum (keys(%live))) {

        my $do_insert = 0;


        ### insert all Category B's
        if ( $category{$var_id} eq "B"){
                $do_insert = 1;
        }

        ### the oldest 50% of Category C's - counted once every 6 months
        if ($category{$var_id} eq "C" ){#&& !$sixmonth_count{$var_id} ){
                if ( ($c_loop / $num_c) < 0.51 && !$sixmonth_count{$var_id}) {
                        $do_insert = 1;
                }
                $c_loop++;
        }

        ### the oldest 25% of Category D's - counted once a year
        if ($category{$var_id} eq "D" ){#&& !$yearly_count{$var_id} ){
                if ( ($d_loop / $num_d) < 0.26 && !$yearly_count{$var_id}) {
                        $do_insert = 1;
                }
                $d_loop++;
        }

        if ($do_insert == 1) {
            foreach my $location_id ( keys (%{$stock{$var_id}}) ) {
                if (!$date{$var_id}{$location_id}) {
                    ####### $ins_sth->execute($var_id, $location_id, $category{$var_id});

                    if ($category{$var_id} eq "B"){ $totalB++; }
                    if ($category{$var_id} eq "C"){ $totalC++; }
                    if ($category{$var_id} eq "D"){ $totalD++; }
                } 
            }
        }
}

print "B: $totalB\nC: $totalC\nD: $totalD\n";

sub hashValueDescendingNum {
   $sales{$b} <=> $sales{$a};
}


sub hashValueAscendingNum {
   $live{$a} <=> $live{$b};
}




__END__

