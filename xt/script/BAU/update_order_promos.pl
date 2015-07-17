#!/opt/xt/xt-perl/bin/perl -w

use strict;
use lib "/opt/xt/deploy/xtracker/lib/";
use warnings;


use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long;
use XTracker::Database qw( :common );
use XTracker::Database::Product qw( get_fcp_sku );
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

print "Preparing Queries ..\n";

$sql = "UPDATE link_shipment__promotion SET promotion = ? WHERE shipment_id = ?";
my $upd_shipment_promo = $dbh->prepare($sql);

$sql = "UPDATE link_shipment_item__promotion SET promotion = ? WHERE shipment_item_id = ?";
my $upd_shipment_item_promo = $dbh->prepare($sql);

$sql = 'SELECT id, name, web_name FROM channel ORDER BY id';
my $channels = $dbh->prepare($sql);
$channels->execute();

while (my $r = $channels->fetchrow_hashref) {
    my $channel_name = (split(/-/,$r->{web_name}))[0];

    if ($channel_name ne 'JC') {

        my $transfer_dbh_ref = get_transfer_sink_handle({ environment => 'live', channel => $channel_name });

        print "$channel_name ($r->{id})\n";

        $web_dbh{$r->{id}} = { 
            name           => $channel_name,
            dbh            => $transfer_dbh_ref->{dbh_sink},
            qry_order      => $transfer_dbh_ref->{dbh_sink}->prepare("
                                SELECT 
                                        ed.internal_title
                                FROM
                                        event_applied ea, event_detail ed
                                WHERE
                                        ea.order_id = ? 
                                        AND ed.id = ea.promotion_id
                                        AND ed.discount_type = 'free_shipping'
                        "),
            qry_order_item => $transfer_dbh_ref->{dbh_sink}->prepare("
                                SELECT
                                        ed.internal_title
                                FROM
                                        order_item oi, event_applied_item eai, event_detail ed
                                WHERE
                                        oi.order_id = ?
                                        AND oi.sku = ? 
                                        AND eai.order_item_id = oi.id
                                        AND ed.id = eai.promotion_id
                                        AND ed.event_type_id in (1,2)
                        "),
        }

    }
}

$schema->txn_begin();
eval {
    print "Selecting unknown order promotions ..\n";

    $sql = 
        "SELECT
                        o.id,
                        o.order_nr,
                        o.date,
                        o.channel_id,
                        los.shipment_id,
                        lsp.promotion
                FROM
                        orders o, link_orders__shipment los, link_shipment__promotion lsp
                WHERE
                        o.date > '2011-07-03'
                        AND los.orders_id = o.id
                        AND lsp.shipment_id = los.shipment_id
                        AND lsp.promotion = 'Unknown_from_web'
                ORDER BY
                        o.id";

    my $unknown_order_promos = $dbh->prepare($sql);
    $unknown_order_promos->execute();

    while (my $r = $unknown_order_promos->fetchrow_hashref) {

        my $promo_title = $r->{promotion};
        $web_dbh{$r->{channel_id}}->{qry_order}->execute($r->{order_nr});
        if (my $promo = $web_dbh{$r->{channel_id}}->{qry_order}->fetchrow_hashref()) {
            $upd_shipment_promo->execute($promo->{internal_title},$r->{shipment_id});
            $promo_title = $promo->{internal_title};
        }

        print "$r->{id}\t".sprintf("%-15s",$r->{order_nr})."\t$r->{date}\t$web_dbh{$r->{channel_id}}->{name}\t$r->{promotion}\t=>\t$promo_title\n";

    }

    print "Selecting unknown order item promotions ..\n";

    $sql = 
        "SELECT
                        o.id,
                        o.order_nr,
                        o.date,
                        o.channel_id,
                        los.shipment_id,
                        si.id shipment_item_id,
                        si.variant_id,
                        lsip.promotion
                FROM
                        orders o, link_orders__shipment los, shipment_item si, link_shipment_item__promotion lsip
                WHERE
                        o.date > '2011-07-03'
                        AND los.orders_id = o.id
                        AND si.shipment_id = los.shipment_id
                        AND lsip.shipment_item_id = si.id
                        AND lsip.promotion = 'Unknown_from_web'
                ORDER BY
                        o.id";

    my $unknown_order_item_promos = $dbh->prepare($sql);
    $unknown_order_item_promos->execute();

    while (my $r = $unknown_order_item_promos->fetchrow_hashref) {

        my $promo_title = $r->{promotion};
        my $sku = get_fcp_sku( $dbh, { type => 'variant_id', id => $r->{variant_id} } );
        $web_dbh{$r->{channel_id}}->{qry_order_item}->execute($r->{order_nr}, $sku );

        if (my $promo = $web_dbh{$r->{channel_id}}->{qry_order_item}->fetchrow_hashref()) { 
            $upd_shipment_item_promo->execute($promo->{internal_title},$r->{shipment_item_id});
            $promo_title = $promo->{internal_title};
        }
        print "$r->{id}\t".sprintf("%-15s",$r->{order_nr})."\t$r->{date}\t$web_dbh{$r->{channel_id}}->{name}\t$r->{shipment_item_id}\t$r->{promotion}\t=>\t$promo_title\n";

    }

    for (keys %web_dbh) {
        $web_dbh{$_}->{qry_order}->finish();
        $web_dbh{$_}->{qry_order_item}->finish();
        $web_dbh{$_}->{dbh}->disconnect() 
    }

};

if (my $err = $@) {
    print "Error : $err\n";
    $schema->txn_rollback();
}
else {
    #        $schema->txn_rollback();
    $schema->txn_commit();
}

1;
