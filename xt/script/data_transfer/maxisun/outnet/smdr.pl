#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;
use Getopt::Long;
use DateTime;

my $dbh         = read_handle();
my $outdir      = undef;
my $channel_id  = undef;
my $dt          = DateTime->now(time_zone => "local");
my @orders      = ();

my %promo_data      = ();

my $to          = $dt->date;
my $from        = $dt->subtract( days => 1 )->date;

GetOptions(
    'outdir=s'      => \$outdir,
    'channel_id=s'  => \$channel_id,
);

die 'No output directory defined' if not defined $outdir;
die 'No channel id defined' if not defined $channel_id;


# open output file and write header record
open my $fh, '>', '/var/data/xt_static/data/maxisun/'.$outdir.'/smdr.csv' || die "Couldn't open output file: $!";
print $fh "reference~date~empty1~airway_bill~currency~value~quantity~sku~designer_id~season_id~country_code~empty2~promo_code~empty3~order_number~empty4~empty5~type\r\n";


# Promo flags
# 1 = Markdown
# 2 = Permanent Discount Merchandise
# 3 = Promo Discount Merchandise

# get promo data
my $qry = "select visible_id, internal_title, end_date from event.detail where internal_title != ''";
my $sth = $dbh->prepare($qry);
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ){
        $promo_data{$row->{internal_title}} = $row;
}

$qry = "
select ri.id, cp.psp_ref as basket_nr, o.basket_nr as old_basket, o.order_nr, s.return_airway_bill,
p.legacy_sku, p.designer_id, p.season_id, ri.return_type_id,
r.rma_number, ren.renumeration_type_id, reni.unit_price, reni.tax, reni.duty,
to_char(min(rsl.date), 'DDMMYYYY') as return_date, cur.currency, pa.percentage, oa.country, ctry.code as country_code, oa.county, 0 as discount_value, '' as promo_name, 1 as type
from orders o left join orders.payment cp on o.id = cp.orders_id, link_orders__shipment los, shipment s, order_address oa, country ctry, return_item ri, return r, renumeration
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
and oa.country = ctry.country
and o.channel_id = ?
group by ri.id, cp.psp_ref, o.basket_nr, o.order_nr, s.return_airway_bill,
p.legacy_sku, p.designer_id, p.season_id, ri.return_type_id,
r.rma_number, ren.renumeration_type_id, reni.unit_price, reni.tax, reni.duty,
cur.currency, pa.percentage, oa.country, ctry.code, oa.county, discount_value, promo_name, type

UNION

select ri.id, cp.psp_ref as basket_nr, o.basket_nr as old_basket, o.order_nr, s.return_airway_bill,
p.legacy_sku, p.designer_id, p.season_id, ri.return_type_id,
r.rma_number, ren.renumeration_type_id, reni.unit_price, reni.tax, reni.duty,
to_char(min(rsl.date), 'DDMMYYYY') as return_date, cur.currency, 0 as percentage, oa.country, ctry.code as country_code, oa.county, link.unit_price as discount_value, link.promotion as promo_name, 3 as type 
from orders o left join orders.payment cp on o.id = cp.orders_id, link_orders__shipment los, shipment s, order_address oa, country ctry, return_item ri, return r, renumeration
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
and o.channel_id = ?
and oa.country = ctry.country
group by ri.id, cp.psp_ref, o.basket_nr, o.order_nr, s.return_airway_bill,
p.legacy_sku, p.designer_id, p.season_id, ri.return_type_id,
r.rma_number, ren.renumeration_type_id, reni.unit_price, reni.tax, reni.duty,
cur.currency, percentage, oa.country, ctry.code, oa.county, discount_value, promo_name, type
";

$sth = $dbh->prepare($qry);

$sth->execute($from, $to, $channel_id, $from, $to, $channel_id);

while( my $row = $sth->fetchrow_hashref() ){

    if ($row->{return_airway_bill} eq "none"){
        $row->{return_airway_bill} = "";
    }

    if (!$row->{basket_nr}){
        $row->{basket_nr} = $row->{old_basket};
    }

    my $date_field = $row->{return_date};

    my $discount = 0;
    my $promo_code = 0;

    if ($row->{percentage} != 0){
        $discount = sprintf( "%.2f", (($row->{unit_price} / ( 100 - $row->{percentage})) * 100) - $row->{unit_price} );
    }
    else {
        $discount = $row->{discount_value};

        # check if it's a permanent discount rather than promotional - no end date to promo
        if ( !$promo_data{ $row->{promo_name} }{end_date} ){
            $row->{type} = 2;
        }

        if ( $promo_data{ $row->{promo_name} }{visible_id} ){
               $promo_code = $promo_data{ $row->{promo_name} }{visible_id};
        }
    }


    print $fh "$row->{order_nr}~$date_field~~$row->{return_airway_bill}~$row->{currency}~$discount~1~$row->{legacy_sku}~$row->{designer_id}~$row->{season_id}~$row->{country_code}~~$promo_code~~$row->{order_nr}~~~$row->{type}\r\n";


}


close $fh;

$dbh->disconnect();



