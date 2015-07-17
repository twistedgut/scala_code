#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib/";
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Database 'xtracker_schema';

my $qry1 ="select id from variant where product_id = ? and size_id = ? and type_id = 1";
my $qry2 ="select so.product_id, so.purchase_order_id from stock_order so, stock_order_item soi, purchase_order po
                        where soi.variant_id = ?
                        and soi.stock_order_id = so.id
                        and so.purchase_order_id = po.id
                        and po.type_id = 1";
my $qry3 ="insert into stock_order values (default, ?, ?, null, null, 1, '', 2, false, false)";
my $qry4 ="select id from stock_order where product_id = ? and purchase_order_id = ? and type_id = 2 order by id desc limit 1";
my $qry5 ="insert into stock_order_item values (default, ?, ?, ?, 1, 0, false)";
my $qry6 ="update purchase_order set status_id = 2 where id = ?";
my $qry7 ="update stock_order set status_id = 2 where id = ?";

open (my $IN,'<',"replacements.txt") || warn "Cannot open site input file: $!";

my $schema = xtracker_schema() || die print "Error: Unable to connect to DB";
while ( my $line = <$IN> ) {

    my ($sku, $qty) = split(/,/, $line);
    chomp($qty);

    my ($prod_id, $size_id) = split(/-/, $sku);

    print "Processing: $sku - $qty\n";

    eval {

        my $variant_id = 0;
        my $product_id = 0;
        my $po_id = 0;

        $schema->txn_do(sub{
            my $dbh = $schema->storage->dbh;
            my $sth1 = $dbh->prepare($qry1);
            my $sth2 = $dbh->prepare($qry2);
            my $sth3 = $dbh->prepare($qry3);
            my $sth4 = $dbh->prepare($qry4);
            my $sth5 = $dbh->prepare($qry5);
            my $sth6 = $dbh->prepare($qry6);
            my $sth7 = $dbh->prepare($qry7);

            $sth1->execute($prod_id, $size_id);
            while ( my $row = $sth1->fetchrow_arrayref() ) {
                $variant_id = $row->[0];
            }

            if ($variant_id > 0) {
                $sth2->execute($variant_id);
                while ( my $row = $sth2->fetchrow_arrayref() ) {
                        $product_id = $row->[0];
                        $po_id = $row->[1];
                }

                if ($product_id > 0 && $po_id > 0) {

                    $sth6->execute($po_id);

                    my $stock_order_id = 0;

                    $sth4->execute($product_id, $po_id);
                    while ( my $row = $sth4->fetchrow_arrayref() ) {
                        $stock_order_id = $row->[0];
                    }

                    if ($stock_order_id == 0){

                        $sth3->execute($product_id, $po_id);

                        $sth4->execute($product_id, $po_id);
                        while ( my $row = $sth4->fetchrow_arrayref() ) {
                                $stock_order_id = $row->[0];
                        }
                    }

                    if ($stock_order_id > 0) {
                        $sth5->execute($stock_order_id, $variant_id, $qty);
                    }
                    else {
                        print "couldn't find new stock order\n";
                    }
                }
                else {
                    print "couldn't find a purchase order\n";
                }
            }
            else {
                print "couldn't find variant\n";
            }
        });
        print "Imported OK\n";
    };

    if ($@) {
        print $@."\n";
    }
}

close($IN);
