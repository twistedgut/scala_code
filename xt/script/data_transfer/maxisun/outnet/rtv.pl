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
my %data        = ();

my $to          = $dt->date;
my $from        = $dt->subtract( days => 1 )->date;

GetOptions(
    'outdir=s'      => \$outdir,
    'channel_id=s'  => \$channel_id,
);

die 'No output directory defined' if not defined $outdir;
die 'No channel id defined' if not defined $channel_id;


# open output file and write header record
open my $fh, '>', '/var/data/xt_static/data/maxisun/'.$outdir.'/dgr.csv' || die "Couldn't open output file: $!";
print $fh "reference~date~empty1~supplier_name~currency~supplier_code~value~quantity~sku~designer_id~season_id~country_code~empty2~type~empty3~purchase_order_number~empty4~empty5~type\r\n";


# set up sub query to get rtv shipment data
my $sub_qry = "
SELECT rsd.id as identifier, rsd.rtv_shipment_id, rsd.rma_request_detail_id, sum(rsd.quantity) as quantity, rrdt.type, p.legacy_sku, p.designer_id, p.season_id, c.code as country_of_origin, sup.code as supplier_code, sup.description as supplier_name, pri.wholesale_price, cur.currency, po.purchase_order_number
FROM rtv_shipment_detail rsd, rma_request_detail rrd, rma_request_detail_type rrdt, variant v, product p, legacy_designer_supplier lds, supplier sup, shipping_attribute sa LEFT JOIN country c ON sa.country_id = c.id, price_purchase pri, currency cur, stock_order so, purchase_order po
WHERE rsd.id = ?
AND rsd.rma_request_detail_id = rrd.id
AND rrd.type_id = rrdt.id
AND rrd.variant_id = v.id
AND v.product_id = p.id
AND p.id = sa.product_id
AND p.designer_id = lds.designer_id
AND lds.supplier_id = sup.id
AND p.id = pri.product_id
AND pri.wholesale_currency_id = cur.id
AND p.id = so.product_id
AND so.purchase_order_id = po.id
AND po.type_id = 1
AND so.type_id = 1
AND so.id = (SELECT MIN(id) FROM stock_order WHERE product_id = p.id)
GROUP BY rsd.id, rsd.rtv_shipment_id, rsd.rma_request_detail_id, rrdt.type, p.legacy_sku, p.designer_id, p.season_id, c.code, sup.code, sup.description, pri.wholesale_price, cur.currency, po.purchase_order_number
";
my $sub_sth = $dbh->prepare($sub_qry);


# get all RTV shipments dispatched within date range specified
my $qry = "select rsl.rtv_shipment_detail_id, to_char(min(rsl.date_time), 'DDMMYYYY') as date 
            from rtv_shipment rs, rtv_shipment_detail rsd, rtv_shipment_detail_status_log rsl
            where rsl.rtv_shipment_detail_status_id = 6 
            and rsl.rtv_shipment_detail_id = rsd.id
            and rsd.rtv_shipment_id = rs.id
            and rs.channel_id = ?
            group by rsl.rtv_shipment_detail_id 
            having min(rsl.date_time) between ? and ?";
my $sth = $dbh->prepare($qry);
$sth->execute($channel_id, $from, $to);

while( my $record = $sth->fetchrow_hashref() ){
    
    # get shipment info
    $sub_sth->execute($record->{rtv_shipment_detail_id});

    while( my $sub_record = $sub_sth->fetchrow_hashref() ){

        $sub_record->{purchase_order_number} = substr $sub_record->{purchase_order_number}, -15, 15;

        $sub_record->{line_amount} = $sub_record->{wholesale_price} * $sub_record->{quantity};

        # strip out restricted chars
        $sub_record->{purchase_order_number}    =~ s/[,\'\"\r\n]//g;
        $sub_record->{supplier_name}            =~ s/[,\'\"\r\n]//g;
       
        print $fh "$sub_record->{identifier}~$record->{date}~~$sub_record->{supplier_name}~$sub_record->{currency}~$sub_record->{supplier_code}~$sub_record->{line_amount}~$sub_record->{quantity}~$sub_record->{legacy_sku}~$sub_record->{designer_id}~$sub_record->{season_id}~$sub_record->{country_of_origin}~~$sub_record->{type}~~$sub_record->{purchase_order_number}~~~1\r\n";
    }
}

close $fh;


$dbh->disconnect();

