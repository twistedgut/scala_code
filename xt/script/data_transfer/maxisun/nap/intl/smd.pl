#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database 'read_handle';
use XTracker::Constants::FromDB qw( :shipment_item_status );

my $dbh = read_handle();

# Promo flags
# 1 = Markdown
# 2 = Permanent Discount Merchandise
# 3 = Permanent Discount Shipping
# 4 = Promo Discount Merchandise
# 5 = Promo Discount Shipping


# get promo data
my %promo_data = ();
my $qry = "select visible_id, internal_title, end_date from event.detail where internal_title != ''";
my $sth = $dbh->prepare($qry);
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ){
        $promo_data{$row->{internal_title}} = $row;
}

my @orders   = ();
my %giftcert = ();

my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst)=localtime(time); $month++; $year = $year+1900;

my $start = ((localtime(time-86400))[5] + 1900)."-".((localtime(time-86400))[4] + 1)."-".((localtime(time-86400))[3]);
my $end = $year."-".$month."-".$day;
my %shipments = ();
my %shipment_item = ();

$qry = "select o.order_nr, o.id as orders_id, o.date, o.basket_nr, s.id as
shipment_id, s.outward_airway_bill, s.shipping_charge, s.shipment_type_id,
oa.country, to_char(sisl.date, 'DDMMYYYY') as dispatch_date, c.currency 
    from orders o, link_orders__shipment los, shipment s, shipment_item si, order_address oa,
    shipment_item_status_log sisl, currency c 
    where sisl.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED
    and sisl.date between ? and ?
    and sisl.shipment_item_id = si.id 
    and si.shipment_id = s.id
    and s.shipment_class_id = 1
    and s.id = los.shipment_id
    and los.orders_id = o.id
    and s.shipment_address_id = oa.id
    and o.currency_id = c.id
    and o.channel_id = 1";

$sth = $dbh->prepare($qry);
$sth->execute($start, $end);

while( my $row = $sth->fetchrow_hashref() ){
    $shipments{$row->{shipment_id}} = $row;
}

$qry = "
select si.id, si.shipment_id, si.unit_price, si.variant_id, p.legacy_sku, p.style_number, p.designer_id, d.designer, p.season_id, s.season, pa.percentage, '' as promo_name, 1 as type
        from shipment_item_status_log sisl, shipment_item si, variant v, product p, designer d, season s, link_shipment_item__price_adjustment link, price_adjustment pa
        where sisl.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED
    and sisl.date between ? and ?
    and sisl.shipment_item_id = si.id
        and si.variant_id = v.id
        and v.product_id = p.id
        and p.designer_id = d.id
        and p.season_id = s.id
    and si.id = link.shipment_item_id
    and link.price_adjustment_id = pa.id
    UNION
    select si.id, si.shipment_id, link.unit_price, si.variant_id, p.legacy_sku, p.style_number, p.designer_id, d.designer, p.season_id, s.season, 0 as percentage, link.promotion as promo_name, 4 as type
        from shipment_item_status_log sisl, shipment_item si, variant v, product p, designer d, season s, link_shipment_item__promotion link
        where sisl.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED
    and sisl.date between ? and ?
    and sisl.shipment_item_id = si.id
        and si.variant_id = v.id
        and v.product_id = p.id
        and p.designer_id = d.id
        and p.season_id = s.id
        and si.id = link.shipment_item_id
    UNION
    select si.id, si.shipment_id, round((link.value / count(si2.id)), 2) as unit_price, si.variant_id, p.legacy_sku, p.style_number, p.designer_id, d.designer, p.season_id, s.season, 0 as percentage, link.promotion as promo_name, 5 as type
        from shipment_item_status_log sisl, shipment_item si, variant v, product p, designer d, season s, link_shipment__promotion link, shipment_item si2
        where sisl.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED
        and sisl.date between ? and ?
        and sisl.shipment_item_id = si.id
        and si.variant_id = v.id
        and v.product_id = p.id
        and p.designer_id = d.id
        and p.season_id = s.id
        and si.shipment_id = link.shipment_id
    and si.shipment_id = si2.shipment_id
    group by si.id, si.shipment_id, si.variant_id, p.legacy_sku, p.style_number, p.designer_id, d.designer, p.season_id, s.season, link.value, link.promotion";
$sth = $dbh->prepare($qry);
$sth->execute($start, $end, $start, $end, $start, $end);

my $counter = 1;

while( my $row = $sth->fetchrow_hashref() ){
    $shipment_item{$row->{shipment_id}}{$counter} = $row;
    $counter++;
}


open my $fh, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/intl/csv/smd.csv" || die "Couldn't open file: $!";

foreach my $shipment_id (keys %shipments) {
    ## no critic(ProhibitDeepNests)

    if ($shipments{$shipment_id}{order_nr}) {

        foreach my $itemid (keys %{$shipment_item{$shipment_id}}) {


            my $discount = 0;
            my $promo_code = 0;

            if ( $shipment_item{$shipment_id}{$itemid}{percentage} != 0 ) {
                $discount = sprintf( "%.2f", (($shipment_item{$shipment_id}{$itemid}{unit_price} / ( 100 - $shipment_item{$shipment_id}{$itemid}{percentage})) * 100) - $shipment_item{$shipment_id}{$itemid}{unit_price} );
            }
            else {
                $discount = $shipment_item{$shipment_id}{$itemid}{unit_price};

                # check if it's a permanent discount rather than promotional - no end date to promo
                if ( !$promo_data{ $shipment_item{$shipment_id}{$itemid}{promo_name} }{end_date} ) {
                    if ($shipment_item{$shipment_id}{$itemid}{type} == 4) {
                        $shipment_item{$shipment_id}{$itemid}{type} = 2;
                    }
                    else {
                        $shipment_item{$shipment_id}{$itemid}{type} = 3;
                    }
                }

                if ( $promo_data{ $shipment_item{$shipment_id}{$itemid}{promo_name} }{visible_id} ) {
                    $promo_code = $promo_data{ $shipment_item{$shipment_id}{$itemid}{promo_name} }{visible_id}; 
                }
            }
            print $fh "$shipments{$shipment_id}{order_nr}~";
            print $fh "$shipments{$shipment_id}{dispatch_date}~";
            print $fh "~";
            print $fh "$shipments{$shipment_id}{outward_airway_bill}~";
            print $fh "$shipments{$shipment_id}{currency}~";
            print $fh "$discount~";
            print $fh "1~";
            print $fh "$shipment_item{$shipment_id}{$itemid}{legacy_sku}~";
            print $fh "$shipment_item{$shipment_id}{$itemid}{designer_id}~";
            print $fh "$shipment_item{$shipment_id}{$itemid}{season_id}~";
            print $fh "$shipments{$shipment_id}{country}~";
            print $fh "~";
            print $fh "$promo_code~";
            print $fh "~";
            print $fh "$shipments{$shipment_id}{order_nr}~";
            print $fh "~";
            print $fh "~";
            print $fh "$shipment_item{$shipment_id}{$itemid}{type}";
            print $fh "\r\n";
        }

    }

}

close $fh;

#}

$dbh->disconnect();

