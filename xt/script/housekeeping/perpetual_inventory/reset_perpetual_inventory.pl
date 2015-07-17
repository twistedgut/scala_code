#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database 'schema_handle';
use XTracker::Database::Stock qw( get_category_summary get_count_summary );

# work out current and next quarter start and end dates
my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst ) = localtime(time);
$month  = ($month + 1);
$year   = ($year + 1900);

my %quarter_dates = (
    "1" => { "start" => "01-01", "end" => '03-31', "start_month" => "Jan", "end_month" => "Mar" },
    "2" => { "start" => "04-01", "end" => '06-30', "start_month" => "Apr", "end_month" => "Jun" },
    "3" => { "start" => "07-01", "end" => '09-30', "start_month" => "Jul", "end_month" => "Sep" },
    "4" => { "start" => "10-01", "end" => '12-31', "start_month" => "Oct", "end_month" => "Dec" },
);

my $last_quarter;
my $last_quarter_year   = $year;
my $next_quarter;
my $next_quarter_year   = $year;

if ($month < 4){
    $next_quarter = 1;
    $last_quarter = 4;
    $last_quarter_year = $last_quarter_year - 1;
}
elsif ($month < 7){
    $next_quarter = 2;
    $last_quarter = 1;
}
elsif ($month < 10){
    $next_quarter = 3;
    $last_quarter = 2;
}
else {
    $next_quarter = 4;
    $last_quarter = 3;
}

my $last_quarter_start  = $last_quarter_year.'-'.$quarter_dates{$last_quarter}{start};
my $last_quarter_end    = $last_quarter_year.'-'.$quarter_dates{$last_quarter}{end};

my $next_quarter_start  = $next_quarter_year.'-'.$quarter_dates{$next_quarter}{start};
my $next_quarter_end    = $next_quarter_year.'-'.$quarter_dates{$next_quarter}{end};

print "Last Quarter: $last_quarter_start to $last_quarter_end\n";
print "Next Quarter: $next_quarter_start to $next_quarter_end\n";

my $schema = schema_handle;
eval{
    $schema->txn_do(sub{
        my $dbh = $schema->storage->dbh;
        # first step record data from previous quarter for reporting on each DC
        _record_count_data( $dbh, $last_quarter_start, $last_quarter_end );

        # next remove all completed counts from stock_count_variant table
        _clear_completed_counts( $dbh, $last_quarter_start, $last_quarter_end );

        # now set up counts for new quarter
        _set_counts( $dbh, $last_quarter_start, $last_quarter_end, $next_quarter_start, $next_quarter_end );
    });
    print "Refresh complete\n\n";
};
if ($@){
    print "Error refreshing counts $@\n\n";
}

exit;

sub _clear_completed_counts {
    my ( $dbh, $quarter_start, $quarter_end ) = @_;

    my $qry = "delete from stock_count_variant where last_count between ? and ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $quarter_start, $quarter_end );

}

sub _record_count_data {
    my ( $dbh, $quarter_start, $quarter_end ) = @_;

    my $categories  = get_category_summary( $dbh );
    my $current     = get_count_summary( $dbh, $quarter_start, $quarter_end );

    my $required = 0;

    foreach my $category_id ( keys %{$categories} ){
        # ignore manual and misc count categories
        if ( $category_id != 5 && $category_id != 6 ){
            $required += $categories->{$category_id}{total};
        }
    }

    print "\n";
    print "$quarter_start, $quarter_end, $required, $current->{counted}, $current->{variances}, $current->{error}\n";

    # create stock count summary record
    my $qry = "insert into stock_count_summary values (default, ?, ?, ?, ?, ?, ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $quarter_start, $quarter_end, $required, $current->{counted}, $current->{variances}, $current->{error} );

    # create stock count category summary records
    foreach my $category_id ( keys %{$categories} ){
        # ignore manual and misc count categories
        if ( $category_id != 5 && $category_id != 6 ){

            print "$categories->{$category_id}{total}, $categories->{$category_id}{done}, $category_id, $quarter_start, $quarter_end\n";

            my $qry = "update stock_count_category_summary set post_counts_required = ?, counts_completed = ? where stock_count_category_id = ? and start_date = ? and end_date = ?";
            my $sth = $dbh->prepare($qry);
            $sth->execute( $categories->{$category_id}{total}, $categories->{$category_id}{done}, $category_id, $quarter_start, $quarter_end );
        }
    }

    print "\n";
}


sub _set_counts {
    my ( $dbh, $quarter_start, $quarter_end, $next_quarter_start, $next_quarter_end ) = @_;

    # set up data sets for setting counts
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

    print "Calculating counts for next quarter: $next_quarter_start to $next_quarter_end...\n";

    ## prepare insert statement for use later on
    ##############################
    my $ins_qry = "insert into stock_count_variant values (?, ?, (select id from stock_count_category where category = ?), null)";
    my $ins_sth = $dbh->prepare($ins_qry);

    ## get value of stock sold over last 3 months
    #############################

    my $qry = "select variant_id, sum(unit_price) from shipment_item where shipment_id in (select id from shipment where shipment_class_id = 1 and date between '$quarter_start' and '$quarter_end') group by variant_id";
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

    $qry = "select v.id, to_char(pc.upload_date, 'YYYYMMDD')
            from variant v, product p, product_channel pc
                where v.product_id = p.id
                and p.id = pc.product_id
                and pc.live = true
                and pc.upload_date < '$quarter_end'";
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

    foreach my $var_id (sort { $sales{$b} <=> $sales{$a} } (keys(%sales))) {

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

    foreach my $var_id (sort { $live{$a} <=> $live{$b} } (keys(%live))) {

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

                    $ins_sth->execute($var_id, $location_id, $category{$var_id});

                    if ($category{$var_id} eq "B"){ $totalB++; }
                    if ($category{$var_id} eq "C"){ $totalC++; }
                    if ($category{$var_id} eq "D"){ $totalD++; }
                }
            }
        }
    }

    print "Cat B: $totalB\nCat C: $totalC\nCat D: $totalD\n";

    # record pre-count data for reporting
    $qry = "insert into stock_count_category_summary values (default, ?, ?, ?, ?, 0, 0)";
    $sth = $dbh->prepare($qry);

    $sth->execute( $next_quarter_start, $next_quarter_end, 1, 0);   # Cat A
    $sth->execute( $next_quarter_start, $next_quarter_end, 2, $totalB);   # Cat B
    $sth->execute( $next_quarter_start, $next_quarter_end, 3, $totalC);   # Cat C
    $sth->execute( $next_quarter_start, $next_quarter_end, 4, $totalD);   # Cat D

    return;
}
