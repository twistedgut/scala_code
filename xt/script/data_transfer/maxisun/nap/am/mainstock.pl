#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;
use XTracker::Constants::FromDB qw( :shipment_item_status );

my $dbh = read_handle();

my %goodsin = ();

my $qry = "select v.product_id, 
                  sum(sp.quantity) as quantity 
           from stock_process sp, delivery_item di, stock_order_item soi, stock_order so, purchase_order po, variant v,
                link_delivery_item__stock_order_item ldi_soi
           where ldi_soi.stock_order_item_id = soi.id
           and soi.variant_id = v.id
           and di.id = ldi_soi.delivery_item_id
           and di.id = sp.delivery_item_id
           and di.cancel = false
           and sp.complete is false
           and soi.stock_order_id = so.id
       and so.purchase_order_id = po.id
       and po.channel_id = 2
           group by v.product_id
           having  sum(sp.quantity) > 0
           union
           select v.product_id, 
                  count(ri.*) as quantity 
           from orders o, link_orders__shipment los, return r, return_item ri, variant v,
                link_delivery_item__return_item ldi_ri
           where ldi_ri.return_item_id = ri.id
           and ri.variant_id = v.id
           and ri.id = ldi_ri.return_item_id
           and ri.return_item_status_id in (2, 3, 6)
           and ri.return_id = r.id
       and r.shipment_id = los.shipment_id
       and los.orders_id = o.id
       and o.channel_id = 2
           group by v.product_id";
my $sth = $dbh->prepare($qry);
$sth->execute();
while( my $row = $sth->fetchrow_hashref() ){
    if ($goodsin{$row->{product_id}}){
        $goodsin{$row->{product_id}} +=  $row->{quantity};
    }
    else {
        $goodsin{$row->{product_id}} = $row->{quantity};
    }
}

my %picked = ();

$qry = "select v.product_id, count(si.*) as quantity
           from orders o, link_orders__shipment los, shipment_item si, variant v
           where si.shipment_item_status_id IN (
             $SHIPMENT_ITEM_STATUS__PICKED,
             $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
             $SHIPMENT_ITEM_STATUS__PACKED )
           and si.variant_id = v.id
           and si.shipment_id = los.shipment_id
           and los.orders_id = o.id
           and o.channel_id = 2
           group by v.product_id
      UNION
        select v.product_id, sum(rsd.quantity) as quantity
from rtv_shipment rs, rtv_shipment_detail rsd, rma_request_detail rrd, variant v
where rsd.status_id between 3 and 5
and rsd.rma_request_detail_id = rrd.id
and rrd.variant_id = v.id
and rsd.rtv_shipment_id = rs.id
            and rs.channel_id = 2
group by v.product_id
";

$sth = $dbh->prepare($qry);
$sth->execute();

while ( my $row = $sth->fetchrow_hashref() ) {
    if ($picked{$row->{product_id}}) {
        $picked{$row->{product_id}} +=  $row->{quantity};
    } else {
        $picked{$row->{product_id}} = $row->{quantity};
    }
}

print "Got goods in\n";

$qry = "
select to_char(current_timestamp, 'DDMMYYYY') as date, p.id as product_id,
p.legacy_sku, p.style_number, s.code, pri.uk_landed_cost, sum(q.quantity) as
quantity, p.designer_id, p.season_id, sa.legacy_countryoforigin
from variant v 
left join quantity q on v.id = q.variant_id and q.channel_id = 2 and q.location_id
not in (select id from location where type_id in (2, 3, 4) and location != 'Transfer Pending') 
and q.location_id != (select id from location where location = 'PRE-ORDER'),
product p 
left join legacy_designer_supplier lds on p.designer_id
= lds.designer_id
left join supplier s on lds.supplier_id = s.id, 
price_purchase pri, shipping_attribute sa
where v.product_id = p.id
and p.id =
pri.product_id
and
p.id
=
sa.product_id
group
by
p.id,
p.legacy_sku,
p.style_number,
s.code,
pri.uk_landed_cost,
p.designer_id,
p.season_id,
sa.legacy_countryoforigin
";

$sth = $dbh->prepare($qry);

open my $fh, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/am/csv/MAINSTOCK.csv" || die "Couldn't open file: $!";

$sth->execute();

print "getting main stock\n";

while ( my $row = $sth->fetchrow_hashref() ) {

    if ($goodsin{$row->{product_id}}) {
        $row->{quantity} = $row->{quantity} + $goodsin{$row->{product_id}};
    }

    if ($picked{$row->{product_id}}) {
        $row->{quantity} = $row->{quantity} + $picked{$row->{product_id}};
    }

    if (!$row->{code}) {
        $row->{code} = "UNKNOWN";
    }


    if ($row->{quantity} && $row->{quantity} > 0) {

        $row->{style_number} =~ s/\n//;
        $row->{style_number} =~ s/\r//;

        if ($row->{legacy_countryoforigin}) {
            $row->{legacy_countryoforigin} =~ s/\n//;
            $row->{legacy_countryoforigin} =~ s/\r//;
        } else {
            $row->{legacy_countryoforigin} = '';
        }

        my $cost = $row->{uk_landed_cost} * $row->{quantity};

        print $fh $row->{legacy_sku}."~";
        print $fh $row->{date}."~";
        print $fh "~";
        print $fh $row->{style_number}."~";
        print $fh "USD~";
        print $fh $row->{code}."~";
        print $fh $cost."~";
        print $fh $row->{quantity}."~";
        print $fh $row->{legacy_sku}."~";
        print $fh $row->{designer_id}."~";
        print $fh $row->{season_id}."~";
        print $fh $row->{legacy_countryoforigin}."~";
        print $fh "~~~~~\r\n";
    }
}

$dbh->disconnect();

close $fh;

