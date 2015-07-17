#!/opt/xt/xt-perl/bin/perl -w
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;
use XTracker::Constants::FromDB qw( :shipment_item_status );

my $dbh = read_handle();

my %goodsin = ();
my %returns = ();
my %faulty = ();
my %rtv = ();
my %surplus = ();

my $qry = "
select v.id,
                  sum(sp.quantity) as quantity, sp.status_id, 1 as type
           from stock_process sp, delivery_item di, stock_order_item soi, stock_order so, purchase_order po, variant v,
                link_delivery_item__stock_order_item ldi_soi
           where ldi_soi.stock_order_item_id = soi.id
           and soi.variant_id = v.id
           and di.id = ldi_soi.delivery_item_id
           and di.id = sp.delivery_item_id
           and di.cancel = false
           and di.status_id < 4
           and di.type_id = 1
           and sp.type_id  = 1
           and sp.complete is false
           and soi.stock_order_id = so.id
       and so.purchase_order_id = po.id
       and po.channel_id = 1
           group by v.id, sp.status_id
           having  sum(sp.quantity) > 0
union
select v.id,
                  sum(sp.quantity) as quantity, sp.status_id, 3 as type
           from stock_process sp, delivery_item di, stock_order_item soi, stock_order so, purchase_order po, variant v,
                link_delivery_item__stock_order_item ldi_soi
           where ldi_soi.stock_order_item_id = soi.id
           and soi.variant_id = v.id
           and di.id = ldi_soi.delivery_item_id
           and di.id = sp.delivery_item_id
           and di.cancel = false
           and di.status_id < 4
           and sp.status_id < 4
           and di.type_id = 1
           and sp.type_id = 2
           and sp.complete is false
           and soi.stock_order_id = so.id
       and so.purchase_order_id = po.id
       and po.channel_id = 1
           group by v.id, sp.status_id
           having  sum(sp.quantity) > 0

union
select v.id,
                  sum(sp.quantity) as quantity, sp.status_id, 4 as type
           from stock_process sp, delivery_item di, stock_order_item soi, stock_order so, purchase_order po, variant v,
                link_delivery_item__stock_order_item ldi_soi
           where ldi_soi.stock_order_item_id = soi.id
           and soi.variant_id = v.id
           and di.id = ldi_soi.delivery_item_id
           and di.id = sp.delivery_item_id
           and di.cancel = false
           and di.status_id < 4
                and sp.status_id < 4
           and di.type_id = 1
           and sp.type_id = 4
           and sp.complete is false
           and soi.stock_order_id = so.id
       and so.purchase_order_id = po.id
       and po.channel_id = 1
           group by v.id, sp.status_id
           having  sum(sp.quantity) > 0

           union
            select v.id, count(ri.*) as quantity, ri.return_item_status_id as status_id, 2 as type
            from orders o, link_orders__shipment los, return r, return_item ri, variant v, link_delivery_item__return_item ldi_ri, stock_process sp
            where ldi_ri.return_item_id = ri.id
                and ldi_ri.delivery_item_id = sp.delivery_item_id
            and sp.status_id < 4
                and sp.type_id != 5
                and sp.complete is false
            and ri.variant_id = v.id
            and ri.id = ldi_ri.return_item_id
            and ri.return_item_status_id in (2, 3, 4, 5, 6)
            and ri.return_id = r.id
       and r.shipment_id = los.shipment_id
       and los.orders_id = o.id
       and o.channel_id = 1
            group by v.id, ri.return_item_status_id
        union
        select v.id,
                  sum(sp.quantity) as quantity, sp.status_id, 5 as type
           from stock_process sp, delivery_item di, stock_order_item soi, stock_order so, purchase_order po, variant v,
                link_delivery_item__stock_order_item ldi_soi
           where ldi_soi.stock_order_item_id = soi.id
           and soi.variant_id = v.id
           and di.id = ldi_soi.delivery_item_id
           and di.id = sp.delivery_item_id
           and di.cancel = false
           and di.status_id < 4
           and di.type_id = 1
           and sp.type_id = 3
           and sp.status_id = 1
           and sp.complete is false
           and soi.stock_order_id = so.id
       and so.purchase_order_id = po.id
       and po.channel_id = 1
           group by v.id, sp.status_id
           having  sum(sp.quantity) > 0
           ";
my $sth = $dbh->prepare($qry);
$sth->execute();
while ( my $row = $sth->fetchrow_hashref() ) {
    if ($row->{type} == 1) {
        if ( $goodsin{ $row->{id} }{ $row->{status_id} }) {
            $goodsin{$row->{id}}{$row->{status_id}}{qty} +=  $row->{quantity};
        }
        else {
            $goodsin{$row->{id}}{$row->{status_id}}{qty} = $row->{quantity};
        }
    }
    elsif ($row->{type} == 3) {
        if ( $faulty{ $row->{id} }) {
            $faulty{ $row->{id}} += $row->{quantity};
        }
        else {
            $faulty{ $row->{id}} = $row->{quantity};
        }
    }
    elsif ($row->{type} == 4) {

        if ( $rtv{ $row->{id} }) {
            $rtv{ $row->{id}} += $row->{quantity};
        }
        else {
            $rtv{ $row->{id}} = $row->{quantity};
        }

    }
    elsif ($row->{type} == 5) {

        if ( $surplus{ $row->{id} }) {
            $surplus{ $row->{id}} += $row->{quantity};
        }
        else {
            $surplus{ $row->{id}} = $row->{quantity};
        }

    }
    else {
        if ($returns{$row->{id}}{$row->{status_id}}) {
            $returns{$row->{id}}{$row->{status_id}}{qty} +=  $row->{quantity};
        }
        else {
            $returns{$row->{id}}{$row->{status_id}}{qty} = $row->{quantity};
        }

    }
}

my %picked = ();

$qry = "select v.id as var_id, count(si.*) as quantity
           from orders o, link_orders__shipment los, shipment_item si, variant v
           where si.shipment_item_status_id IN (
             $SHIPMENT_ITEM_STATUS__PICKED,
             $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
             $SHIPMENT_ITEM_STATUS__PACKED )
           and si.variant_id = v.id
           and si.shipment_id = los.shipment_id
           and los.orders_id = o.id
           and o.channel_id = 1
           group by v.id";

$sth = $dbh->prepare($qry);
$sth->execute();

while ( my $row = $sth->fetchrow_hashref() ) {
    if ($picked{$row->{var_id}}) {
        $picked{$row->{var_id}} +=  $row->{quantity};
    }
    else {
        $picked{$row->{var_id}} = $row->{quantity};
    }
}

my %rtv_picked = ();

$qry = "
select v.id as var_id, sum(rsd.quantity) as quantity
from rtv_shipment rs, rtv_shipment_detail rsd, rma_request_detail rrd, variant v
where rsd.status_id between 3 and 5
and rsd.rma_request_detail_id = rrd.id
and rrd.variant_id = v.id
and rsd.rtv_shipment_id = rs.id
and rs.channel_id = 1
group by v.id
";

$sth = $dbh->prepare($qry);
$sth->execute();

while ( my $row = $sth->fetchrow_hashref() ) {
    if ($rtv_picked{$row->{var_id}}) {
        $rtv_picked{$row->{var_id}} +=  $row->{quantity};
    }
    else {
        $rtv_picked{$row->{var_id}} = $row->{quantity};
    }
}

print "Got goods in\n";

my %got = ();

$qry = "
select to_char(current_timestamp, 'DDMMYYYY') as date, v.id as var_id, v.product_id,
v.legacy_sku, v.product_id || '-' || sku_padding(v.size_id) as sku, p.id, p.style_number, s.code, pri.uk_landed_cost, sum(q.quantity) as
quantity, p.designer_id, p.season_id, sa.legacy_countryoforigin, l.location
from variant v 
    left join quantity q on v.id = q.variant_id and q.channel_id = 1 and q.location_id not in (select id from location where type_id in (2, 3, 4, 6) and location != 'Transfer Pending') and q.location_id != (select id from location where location = 'PRE-ORDER')
    left join location l on q.location_id = l.id, 
product p 
    left join legacy_designer_supplier lds on p.designer_id = lds.designer_id
    left join supplier s on lds.supplier_id = s.id, 
price_purchase pri, shipping_attribute sa
where v.product_id = p.id
and p.id = pri.product_id
and p.id = sa.product_id
group by v.id, v.legacy_sku,p.id, v.product_id, v.size_id, p.style_number, s.code, pri.uk_landed_cost, p.designer_id, p.season_id, sa.legacy_countryoforigin, l.location
";

$sth = $dbh->prepare($qry);

open my $fh, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/intl/csv/MAINSTOCK_AUDIT.csv" || die "Couldn't open file: $!";

$sth->execute();

print "getting main stock\n";

while ( my $row = $sth->fetchrow_hashref() ) {

    if (!$row->{code}) {
        $row->{code} = '';
    }

    if (!$row->{uk_landed_cost}) {
        $row->{uk_landed_cost} = 0;
    }

    $row->{style_number} =~ s/\n//g;
    $row->{style_number} =~ s/\r//g;
    $row->{style_number} =~ s/,//g;

    if ($goodsin{$row->{var_id}} && !$got{$row->{var_id}}{goodsin}) {
        $got{$row->{var_id}}{goodsin} = 1;

        foreach my $status_id (keys %{$goodsin{$row->{var_id}}} ) {
            my $cost = $row->{uk_landed_cost} * $goodsin{$row->{var_id}}{$status_id}{qty};

            my $status = "UNKNOWN $status_id";

            if ($status_id == 1) {
                $status = "Quality Control";
            } elsif ($status_id == 2) {
                $status = "Bag & Tag";
            } elsif ($status_id == 3) {
                $status = "Put Away (Goods In)";
            } elsif ($status_id == 5) {
                $status = "Dead Stock";
            }

            print $fh "$row->{legacy_sku},$row->{product_id},$row->{sku},$row->{date},,$row->{style_number},,GBP,$row->{code},$cost,$goodsin{$row->{var_id}}{$status_id}{qty},$row->{legacy_sku},$row->{designer_id},$row->{season_id},$status\n";

        }
    }

    if ($faulty{$row->{var_id}} && !$got{$row->{var_id}}{faulty}) {
        $got{$row->{var_id}}{faulty} = 1;

        my $cost = $row->{uk_landed_cost} * $faulty{$row->{var_id}};

        print $fh "$row->{legacy_sku},$row->{product_id},$row->{sku},$row->{date},,$row->{style_number},,GBP,$row->{code},$cost,$faulty{$row->{var_id}},$row->{legacy_sku},$row->{designer_id},$row->{season_id},Faulty\n";

    }

    if ($surplus{$row->{var_id}} && !$got{$row->{var_id}}{surplus}) {
        $got{$row->{var_id}}{surplus} = 1;

        my $cost = $row->{uk_landed_cost} * $surplus{$row->{var_id}};

        print $fh "$row->{legacy_sku},$row->{product_id},$row->{sku},$row->{date},,$row->{style_number},,GBP,$row->{code},$cost,$surplus{$row->{var_id}},$row->{legacy_sku},$row->{designer_id},$row->{season_id},Surplus\n";

    }

    if ($rtv{$row->{var_id}} && !$got{$row->{var_id}}{rtv}) {
        $got{$row->{var_id}}{rtv} = 1;

        my $cost = $row->{uk_landed_cost} * $rtv{$row->{var_id}};

        #print $fh "$row->{legacy_sku},$row->{product_id},$row->{sku},$row->{date},,$row->{style_number},,GBP,$row->{code},$cost,$rtv{$row->{var_id}},$row->{legacy_sku},$row->{designer_id},$row->{season_id},RTV\n";

    }


    if ($returns{$row->{var_id}} && !$got{$row->{var_id}}{returns}) {
        $got{$row->{var_id}}{returns} = 1;

        foreach my $status_id (keys %{$returns{$row->{var_id}}} ) {

            my $cost = $row->{uk_landed_cost} * $returns{$row->{var_id}}{$status_id}{qty};

            my $status = "UNKNOWN $status_id";

            if ($status_id == 2) {
                $status = "Returns QC";
            } elsif ($status_id == 3 || $status_id == 4 || $status_id == 5) {
                $status = "Returns Faulty";
            } elsif ($status_id == 6) {
                $status = "Put Away (Returns)";
            }

            print $fh "$row->{legacy_sku},$row->{product_id},$row->{sku},$row->{date},,$row->{style_number},,GBP,$row->{code},$cost,$returns{$row->{var_id}}{$status_id}{qty},$row->{legacy_sku},$row->{designer_id},$row->{season_id},$status\n";

        }
    }

    if ($picked{$row->{var_id}} && !$got{$row->{var_id}}{picking}) {
        $got{$row->{var_id}}{picking} = 1;

        my $cost = $row->{uk_landed_cost} * $picked{$row->{var_id}};

        print $fh "$row->{legacy_sku},$row->{product_id},$row->{sku},$row->{date},,$row->{style_number},,GBP,$row->{code},$cost,$picked{$row->{var_id}},$row->{legacy_sku},$row->{designer_id},$row->{season_id},Picked\n";
    }

    if ($rtv_picked{$row->{var_id}} && !$got{$row->{var_id}}{rtv_picking}) {
        $got{$row->{var_id}}{rtv_picking} = 1;
        my $cost = $row->{uk_landed_cost} * $rtv_picked{$row->{var_id}};

        print $fh "$row->{legacy_sku},$row->{product_id},$row->{sku},$row->{date},,$row->{style_number},,GBP,$row->{code},$cost,$rtv_picked{$row->{var_id}},$row->{legacy_sku},$row->{designer_id},$row->{season_id},RTV Picked\n";
    }


    if ($row->{location} && $row->{quantity} > 0) {

        my $cost = $row->{uk_landed_cost} * $row->{quantity};
        print $fh "$row->{legacy_sku},$row->{product_id},$row->{sku},$row->{date},,$row->{style_number},,GBP,$row->{code},$cost,$row->{quantity},$row->{legacy_sku},$row->{designer_id},$row->{season_id},$row->{location}\n";
    }
}

$dbh->disconnect();

close $fh;

