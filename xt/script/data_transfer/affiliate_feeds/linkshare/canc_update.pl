#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw ( get_database_handle );
use XTracker::Constants::FromDB qw( :shipment_item_status );

my $debug = $ENV{'DEBUG'};

# db handles
my $dbh = get_database_handle( { name => 'xtracker', type => 'readonly' } ) || die "Error: Unable to connect to XT DB";

my %channels = (
    'NET-A-PORTER.COM'  => get_database_handle( { name => 'Web_Live_NAP', type => 'transaction' } ),
    'theOutnet.com'    => get_database_handle( { name => 'Web_Live_OUTNET', type => 'transaction' } ),
    'MRPORTER.COM' => get_database_handle( { name => 'Web_Live_MRP', type => 'transaction' } ),
);


foreach my $channel ( keys %channels ) {

    print "Processing $channel...\n" if $debug;

    my $dbh_web = $channels{ $channel };

    # prepare web queries
    my $sel_qry = "select created_date, amount / quantity as value, currency, site_id, cookie_created_date from affiliate_orderlines where order_id = ? and sku = ? and amount > 0";
    my $sel_sth = $dbh_web->prepare($sel_qry);
    my $ins_qry = "insert into affiliate_orderlines (id, order_id, sku, quantity, amount, currency, created_date, status, site_id, cookie_created_date) values (default, ?, ?, ?, ?, ?, ?, 'READY', ?, ?)";
    my $ins_sth = $dbh_web->prepare($ins_qry);

    my %data = ();

    ### db query to get all returns
    my $qry = "
    select o.order_nr, v.product_id || '-' || sku_padding(v.size_id) as sku
    from renumeration r, renumeration_item ri, shipment_item si, variant v, link_orders__shipment los, orders o
    where r.renumeration_type_id in (1,2)
    and r.renumeration_class_id in (2,3)
    and r.id in (select renumeration_id from renumeration_status_log where renumeration_status_id = 5 and date > current_timestamp - interval '1 day')
    and r.id = ri.renumeration_id
    and ri.shipment_item_id = si.id
    and si.variant_id = v.id
    and r.shipment_id = los.shipment_id
    and los.orders_id = o.id
    and o.channel_id = (select id from channel where name = ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $channel );

    while ( my $row = $sth->fetchrow_hashref() ) {
        if ($data{$row->{order_nr}}{$row->{sku}}{quantity}){
            $data{$row->{order_nr}}{$row->{sku}}{quantity}++;
        }
        else {
            $data{$row->{order_nr}}{$row->{sku}} = $row;
            $data{$row->{order_nr}}{$row->{sku}}{quantity} = 1;
        }
    }

    ### db query to get all cancellations
    $qry = "
    select o.order_nr, v.product_id || '-' || sku_padding(v.size_id) as sku
    from shipment_item si, variant v, link_orders__shipment los, orders o
    where si.id in (select shipment_item_id from shipment_item_status_log where shipment_item_status_id = $SHIPMENT_ITEM_STATUS__CANCELLED and date > current_timestamp - interval '1 day')
    and si.variant_id = v.id
    and si.shipment_id = los.shipment_id
    and los.orders_id = o.id
    and o.channel_id = (select id from channel where name = ?)
    ";
    $sth = $dbh->prepare($qry);
    $sth->execute( $channel );

    while ( my $row = $sth->fetchrow_hashref() ) {

        if ($data{$row->{order_nr}}{$row->{sku}}{quantity}){
            $data{$row->{order_nr}}{$row->{sku}}{quantity}++;
        }
        else {
            $data{$row->{order_nr}}{$row->{sku}} = $row;
            $data{$row->{order_nr}}{$row->{sku}}{quantity} = 1;
        }
    }


    foreach my $order_nr (keys %data){

        foreach my $sku (keys %{$data{$order_nr}} ){

            ### get affiliate tracker id and date from fcp db
            my $aff_track_date;
            my $aff_track_value;
            my $aff_track_currency;
            my $aff_track_site_id;
            my $aff_track_cookie;
            
            $sel_sth->execute($order_nr, $sku);
            
            while ( my $sel_row = $sel_sth->fetchrow_hashref() ) {
                    $aff_track_date     = $sel_row->{created_date};
                    $aff_track_value    = $sel_row->{value};
                    $aff_track_currency = $sel_row->{currency};
                    $aff_track_site_id  = $sel_row->{site_id};
                    $aff_track_cookie   = $sel_row->{cookie_created_date};
            }

            if ($aff_track_date){
                    ### insert row into FCP db                    
                    $ins_sth->execute($order_nr, $sku, $data{$order_nr}{$sku}{quantity}, (($aff_track_value * -1) * $data{$order_nr}{$sku}{quantity}), $aff_track_currency, $aff_track_date, $aff_track_site_id, $aff_track_cookie);
                    print "Inserted for $order_nr.\n" if $debug;
            }
        }
    }

    $dbh_web->commit();
    $dbh_web->disconnect();

}

$dbh->disconnect();
