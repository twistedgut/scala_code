#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw(:common);

my $dbh = get_database_handle(
        {
            name    => 'xtracker',
            type    => 'readonly',
        }
    );

my $dbh_intl = get_database_handle(
        {
            name    => 'XTracker_DC1',
            type    => 'readonly',
        }
    );

my @orders   = ();
my %giftcert = ();

my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst)=localtime(time); $month++; $year = $year+1900;

my $start = ((localtime(time-86400))[5] + 1900)."-".((localtime(time-86400))[4] + 1)."-".((localtime(time-86400))[3]);
my $end = $year."-".$month."-".$day;
# Promo flags
# 1 = Markdown
# 2 = Permanent Discount Merchandise
# 3 = Promo Discount Merchandise

# get promo data
my %promo_data = ();
my $qry = "select visible_id, internal_title, end_date from event.detail where internal_title != ''";
my $sth = $dbh_intl->prepare($qry);
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ){
        $promo_data{$row->{internal_title}} = $row;
}

$qry = "
select ri.id, cp.psp_ref as basket_nr, o.basket_nr as old_basket, o.order_nr, s.return_airway_bill,
p.legacy_sku, p.designer_id, p.season_id, ri.return_type_id,
r.rma_number, ren.renumeration_type_id, reni.unit_price, reni.tax, reni.duty,
to_char(min(rsl.date), 'DDMMYYYY') as return_date, cur.currency, pa.percentage, oa.country, oa.county, 0 as discount_value, '' as promo_name, 1 as type
from orders o left join orders.payment cp on o.id = cp.orders_id, link_orders__shipment los, shipment s, order_address oa, return_item ri, return r, renumeration
ren, renumeration_item reni, variant v, product p,
return_item_status_log rsl, currency cur, link_shipment_item__price_adjustment link, price_adjustment pa
where rsl.date between ? and ?
and rsl.return_item_status_id = 2
and rsl.return_item_id = ri.id
and ri.return_id = r.id
and r.shipment_id = s.id
and s.shipment_address_id = oa.id
and s.id = los.shipment_id
and los.orders_id = o.id
and ri.variant_id = v.id
and v.product_id = p.id
AND ri.shipment_item_id = reni.shipment_item_id
AND ri.shipment_item_id = link.shipment_item_id
AND link.price_adjustment_id = pa.id
AND reni.renumeration_id = ren.id
AND ren.renumeration_class_id = 3
AND ren.renumeration_status_id < 6
AND o.currency_id = cur.id
and o.channel_id = 2
group by ri.id, cp.psp_ref, o.basket_nr, o.order_nr, s.return_airway_bill,
p.legacy_sku, p.designer_id, p.season_id, ri.return_type_id,
r.rma_number, ren.renumeration_type_id, reni.unit_price, reni.tax, reni.duty,
cur.currency, pa.percentage, oa.country, oa.county, discount_value, promo_name, type

UNION

select ri.id, cp.psp_ref as basket_nr, o.basket_nr as old_basket, o.order_nr, s.return_airway_bill,
p.legacy_sku, p.designer_id, p.season_id, ri.return_type_id,
r.rma_number, ren.renumeration_type_id, reni.unit_price, reni.tax, reni.duty,
to_char(min(rsl.date), 'DDMMYYYY') as return_date, cur.currency, 0 as percentage, oa.country, oa.county, link.unit_price as discount_value, link.promotion as promo_name, 3 as type 
from orders o left join orders.payment cp on o.id = cp.orders_id, link_orders__shipment los, shipment s, order_address oa, return_item ri, return r, renumeration
ren, renumeration_item reni, variant v, product p,
return_item_status_log rsl, currency cur, link_shipment_item__promotion link
where rsl.date between ? and ?
and rsl.return_item_status_id = 2
and rsl.return_item_id = ri.id
and ri.return_id = r.id
and r.shipment_id = s.id
and s.shipment_address_id = oa.id
and s.id = los.shipment_id
and los.orders_id = o.id
and ri.variant_id = v.id
and v.product_id = p.id
AND ri.shipment_item_id = reni.shipment_item_id
AND ri.shipment_item_id = link.shipment_item_id
AND reni.renumeration_id = ren.id
AND ren.renumeration_class_id = 3
AND ren.renumeration_status_id < 6
AND o.currency_id = cur.id
and o.channel_id = 2
group by ri.id, cp.psp_ref, o.basket_nr, o.order_nr, s.return_airway_bill,
p.legacy_sku, p.designer_id, p.season_id, ri.return_type_id,
r.rma_number, ren.renumeration_type_id, reni.unit_price, reni.tax, reni.duty,
cur.currency, percentage, oa.country, oa.county, discount_value, promo_name, type
";

$sth = $dbh->prepare($qry);

$sth->execute($start, $end, $start, $end);

open my $fh2, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/am/csv/smdr.csv" || die "Couldn't open file: $!";

while ( my $row = $sth->fetchrow_hashref() ) {

    my $state = "0";

    if ($row->{country} eq "United States") {
        $state = $row->{county};
    }

    if ($row->{return_airway_bill} eq "none") {
        $row->{return_airway_bill} = "";
    }

    if (!$row->{basket_nr}) {
        $row->{basket_nr} = $row->{old_basket};
    }

    my $date_field = $row->{return_date};

    my $discount = 0;
    my $promo_code = '';

    if ($row->{percentage} != 0) {
        $discount = sprintf( "%.2f", (($row->{unit_price} / ( 100 - $row->{percentage})) * 100) - $row->{unit_price} );
    }
    else {
        $discount = $row->{discount_value};

        # check if it's a permanent discount rather than promotional - no end date to promo
        if ( !$promo_data{ $row->{promo_name} }{end_date} ) {
            $row->{type} = 2;
        }

        if ( $promo_data{ $row->{promo_name} }{visible_id} ) {
            $promo_code = $promo_data{ $row->{promo_name} }{visible_id};
        }
    }


    print $fh2 "$row->{order_nr}~";
    print $fh2 "$date_field~";
    print $fh2 "~";
    print $fh2 "$row->{return_airway_bill}~";
    print $fh2 "$row->{currency}~";
    print $fh2 "$discount~";
    print $fh2 "1~";
    print $fh2 "$row->{legacy_sku}~";
    print $fh2 "$row->{designer_id}~";
    print $fh2 "$row->{season_id}~";
    print $fh2 "$row->{country}~";
    print $fh2 "~";
    if ($promo_code) {
        print $fh2 "$promo_code~";
    }
    else {
        print $fh2 "0~";
    }
    print $fh2 "~";
    print $fh2 "$row->{order_nr}~";
    print $fh2 "~";
    print $fh2 "~";
    print $fh2 "$row->{type}";
    print $fh2 "\r\n";


}


close $fh2;


$dbh->disconnect();



