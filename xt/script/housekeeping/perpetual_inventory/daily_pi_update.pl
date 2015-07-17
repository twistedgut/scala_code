#!/opt/xt/xt-perl/bin/perl -w
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Database;
use XTracker::Constants::FromDB qw( :flow_status );

my $dbh = read_handle() || die print "Error: Unable to connect to DB";

### set up data sets
my %current = ();
my %stock = ();
my %counted = ();


## get all existing stock counts
#################################

my $qry = "select variant_id, location_id, stock_count_category_id, last_count from stock_count_variant";
my $sth = $dbh->prepare($qry);
$sth->execute();
while ( my $row = $sth->fetchrow_hashref() ) {
        $current{$$row{variant_id}}{$$row{location_id}} = $row;

        if ($$row{last_count}) {
            $counted{$$row{variant_id}} = 1;
        }
}

## get all located stock
#########################

$qry = "select v.id, q.location_id, q.quantity from variant v, quantity q, location l where v.id = q.variant_id and q.location_id = l.id and q.status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS and l.location != 'GI'";
$sth = $dbh->prepare($qry);
$sth->execute();
while ( my $row = $sth->fetchrow_arrayref() ) {
        $stock{$row->[0]}{$row->[1]}{got} = 1;
        $stock{$row->[0]}{$row->[1]}{quantity} =  $row->[2];
}


### loop through all existing counts and check if locations still valid
foreach my $variant_id ( keys %current ) {

    foreach my $location_id ( keys %{$current{$variant_id}} ) {

        ### not counted yet
        if (!$current{$variant_id}{$location_id}{last_count}) {

            ### count location no longer exists - delete it
            if (!$stock{$variant_id}{ $location_id }) {

                my $qry = "delete from stock_count_variant where variant_id = ? and location_id = ?";
                my $sth = $dbh->prepare($qry);
                $sth->execute($variant_id, $location_id);

                print "Removed -> $variant_id / $location_id\n";
            }
            ### count is a Cat A but we now have stock - delete it
            elsif ($current{$variant_id}{$location_id}{stock_count_category_id} == 1 && $stock{$variant_id}{ $location_id }{quantity} > 0) {

                my $qry = "delete from stock_count_variant where variant_id = ? and location_id = ?";
                my $sth = $dbh->prepare($qry);
                $sth->execute($variant_id, $location_id);

                print "Removed CAT A -> $variant_id / $location_id\n";
            }
            else {
                ### count location is now 0 and current count is not a Category A - change it to a Category A
                if ($stock{$variant_id}{ $location_id }{quantity} == 0 && $current{$variant_id}{$location_id}{stock_count_category_id} > 1) {

                    my $qry = "update stock_count_variant set stock_count_category_id = 1 where variant_id = ? and location_id = ?";
                    my $sth = $dbh->prepare($qry);
                    $sth->execute($variant_id, $location_id);

                    print "CAT A Update -> $variant_id / $location_id\n";
                }
            }
        }
    }
}


### now loop through all stock locations to check for changes
foreach my $variant_id ( keys %stock ) {
    ## no critic(ProhibitDeepNests)

    ### loop through the stock locations and make sure we've got them all
    foreach my $location_id ( keys %{$stock{$variant_id}} ) {

        ### we're missing the location & SKU not counted yet
        if (!$current{$variant_id}{$location_id} && !$counted{$variant_id} ) {

            ### create Cat A if 0 stock level
            if ($stock{$variant_id}{$location_id}{quantity} == 0) {

                my $qry = "insert into stock_count_variant values (?, ?, 1, null)";
                my $sth = $dbh->prepare($qry);
                $sth->execute($variant_id, $location_id);

                print "Created -> $variant_id / $location_id\n";

            }
            ### otherwise use the current stock count category
            else {

                ### check if there is a stock count for the variant
                if ($current{$variant_id}) {

                    my $cat_id = 0;

                    ### get the category id of current stock count
                    foreach my $location_id ( keys %{$current{$variant_id}} ) {
                        ### ignore CAT A and manual requests
                        if ($current{$variant_id}{$location_id}{stock_count_category_id} != 1 && $current{$variant_id}{$location_id}{stock_count_category_id} != 5) {
                            $cat_id = $current{$variant_id}{$location_id}{stock_count_category_id};
                        }
                    }

                    if ($cat_id > 0) {
                        my $qry = "insert into stock_count_variant values (?, ?, ?, null)";
                        my $sth = $dbh->prepare($qry);
                        $sth->execute($variant_id, $location_id, $cat_id);

                        print "Created -> $variant_id / $location_id\n";
                    }
                }
            }

        }

    }

}

