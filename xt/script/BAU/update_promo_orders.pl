#!/opt/xt/xt-perl/bin/perl -w

# http://jira4.nap/browse/APS-918.

use strict;
use lib "/opt/xt/deploy/xtracker/lib/";
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long;
use XTracker::Database qw( :common );
use XTracker::Comms::DataTransfer   qw(:transfer_handles);

use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::Session;

my $schema = get_database_handle( {
    name => 'xtracker_schema',
    type => 'transaction',
} );

my $dbh = $schema->storage->dbh;

my %web_dbh;
my $sql;

my $channel_name = $ARGV[0] || 'x';
my $promo_id = $ARGV[1] || '';

my @channels = ( 'NAP' , 'OUTNET' , 'MRP' );

die 'invalid channel' if (! grep { /$channel_name/ } @channels );
die 'invalid promotion id' if ($promo_id !~ /\d+/);

my $transfer_dbh_ref = get_transfer_sink_handle({ environment => 'live', channel => $channel_name });
my %count = ( total => 0 , updated => 0 );

$schema->txn_begin();

eval {

    $sql = "
                SELECT
                        los.orders_id, los.shipment_id, si.id shipment_item_id
                FROM 
                        orders o, link_orders__shipment los, shipment_item si, variant v
                WHERE o.order_nr = ?
                AND los.orders_id = o.id
                AND si.shipment_id = los.shipment_id
                AND v.id = si.variant_id
                AND v.product_id = ?
                AND v.size_id = ?
                ";

    my $get_shipment_item = $dbh->prepare($sql);

    $sql = "
                SELECT
                        lsip.shipment_item_id
                FROM 
                        link_shipment_item__promotion lsip
                WHERE lsip.shipment_item_id = ? 
                ";

    my $chk_shipment_item_promo = $dbh->prepare($sql);

    $sql = "INSERT INTO link_shipment_item__promotion(shipment_item_id,promotion,unit_price,tax,duty) VALUES(?,?,0,0,0)";
    my $ins_shipment_item_promo = $dbh->prepare($sql);

    $sql = "
                SELECT ed.id, ed.internal_title, oi.order_id, oi.sku 
                FROM event_detail ed, event_applied_item eai, order_item oi 
                WHERE ed.id = ?
                AND eai.promotion_id = ed.id 
                AND oi.id = eai.order_item_id
                ";

    my $web_promo_orders = $transfer_dbh_ref->{dbh_sink}->prepare($sql);
    $web_promo_orders->execute($promo_id);

    while (my $r = $web_promo_orders->fetchrow_hashref) {
        print "$r->{internal_title}\t".sprintf("%-15s",$r->{order_id})."\t$r->{sku}\n";
        $count{total}++;

        my ($product_id, $size_id) = split(/-/,$r->{sku});

        $get_shipment_item->execute($r->{order_id},$product_id,$size_id);
        if (my $r_shipment_item = $get_shipment_item->fetchrow_hashref) {

            $chk_shipment_item_promo->execute($r_shipment_item->{shipment_item_id});

            if (!$chk_shipment_item_promo->fetchrow_hashref) {

                $ins_shipment_item_promo->execute($r_shipment_item->{shipment_item_id},$r->{internal_title});
                $count{updated}++;

            }
        }
    }

    $transfer_dbh_ref->{dbh_sink}->disconnect();

};

if (my $err = $@) {
    print "Error : $err\n";
    $schema->txn_rollback();
}
else {
    $schema->txn_rollback();
    #        $schema->txn_commit();
}

print "$count{total} / $count{updated}\n";

1;
