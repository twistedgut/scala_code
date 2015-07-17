#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw ( read_handle read_handle_dc2);

# db connections
my $dbh_intl = read_handle();
my $dbh_am = read_handle_dc2();


# sync INTL to AM
sync_data($dbh_intl, $dbh_am);

# sync AM to INTL
sync_data($dbh_am, $dbh_intl);


sub sync_data {

    my ($dbh_from, $dbh_to) = @_;


    # set up insert and update for stock_summary_foreign table
    my $ins_qry = "INSERT INTO product.stock_summary_foreign (product_id, ordered, delivered, main_stock, sample_stock, sample_request, reserved, pre_pick, cancel_pending, last_updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

    my $up_qry = "UPDATE product.stock_summary_foreign SET ordered = ?, delivered = ?, main_stock = ?, sample_stock = ?, sample_request = ?, reserved = ?, pre_pick = ?, cancel_pending = ?, last_updated = ? WHERE product_id = ?";


    # get stock summary changes within the last hour (and a bit)
    my $qry = "select * from product.stock_summary where last_updated > current_timestamp - interval '1 hour 5 minutes'";

    #my $qry = "select * from product.stock_summary where product_id in (select id from product where live = false)";
    #my $qry = "select * from product.stock_summary where last_updated > '2008-06-11'";
    #my $qry = "select * from product.stock_summary where product_id not in (select product_id from product.stock_summary_foreign)";


    my $sth = $dbh_from->prepare($qry);
    $sth->execute();

    while (my $row = $sth->fetchrow_hashref) {

        # update
        if ( check_stock_summary_foreign($dbh_to, $row->{product_id}) ) {

            print "Updated: ".$row->{product_id}."\n";
            my $sth = $dbh_to->prepare($up_qry);
            $sth->execute(
                $row->{ordered},
                $row->{delivered},
                $row->{main_stock},
                $row->{sample_stock},
                $row->{sample_request},
                $row->{reserved},
                $row->{pre_pick},
                $row->{cancel_pending},
                $row->{last_updated},
                $row->{product_id}
            );

        }
        # insert
        else {

            print "Inserted: ".$row->{product_id}."\n";

            my $sth = $dbh_to->prepare($ins_qry);
            $sth->execute(
                $row->{product_id},
                $row->{ordered},
                $row->{delivered},
                $row->{main_stock},
                $row->{sample_stock},
                $row->{sample_request},
                $row->{reserved},
                $row->{pre_pick},
                $row->{cancel_pending},
                $row->{last_updated}
            );

        }

    }

}


sub check_stock_summary_foreign {

    my ($dbh, $prod_id) = @_;

    my $got = 0;

    # get stock summary foreign data
    my $qry = "select * from product.stock_summary_foreign where product_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($prod_id);

    while (my $row = $sth->fetchrow_hashref) {
        $got = 1;
    }

    return $got;
}


$dbh_intl->disconnect();
$dbh_am->disconnect();

