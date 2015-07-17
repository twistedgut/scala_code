#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;

my $dbh = read_handle();

my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst)=localtime(time);
$month++;
$year = $year+1900;

my $start = ((localtime(time-86400))[5] + 1900)."-".((localtime(time-86400))[4] + 1)."-".((localtime(time-86400))[3]);
my $end = $year."-".$month."-".$day;

#$start = '2008-03-02';
#$end = '2008-03-15';


# set up sub query to get rtv shipment data
my $sub_qry = "
SELECT rsd.id as identifier, rsd.rtv_shipment_id, rsd.rma_request_detail_id, sum(rsd.quantity) as quantity, rrdt.type, p.legacy_sku, p.designer_id, p.season_id, c.country as country_of_origin, sup.code as supplier_code, sup.description as supplier_name, pri.wholesale_price, cur.currency, po.purchase_order_number
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
AND po.channel_id = 1
AND so.id = (SELECT MIN(id) FROM stock_order WHERE product_id = p.id)
GROUP BY rsd.id, rsd.rtv_shipment_id, rsd.rma_request_detail_id, rrdt.type, p.legacy_sku, p.designer_id, p.season_id, c.country, sup.code, sup.description, pri.wholesale_price, cur.currency, po.purchase_order_number
";
my $sub_sth = $dbh->prepare($sub_qry);


# get all RTV shipments dispatched within date range specified
my $qry = "select rtv_shipment_detail_id, to_char(min(date_time), 'DDMMYYYY') as date from rtv_shipment_detail_status_log where rtv_shipment_detail_status_id = 6 group by rtv_shipment_detail_id having min(date_time) between ? and ?";
my $sth = $dbh->prepare($qry);
$sth->execute($start, $end);

# open output file
open my $fh, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/intl/csv/dgr.csv" || die "Couldn't open file: $!";

while( my $record = $sth->fetchrow_hashref() ){
    
    # get shipment info
    $sub_sth->execute($record->{rtv_shipment_detail_id});

    while( my $sub_record = $sub_sth->fetchrow_hashref() ){

        $sub_record->{purchase_order_number} = substr $sub_record->{purchase_order_number}, -15, 15;

        $sub_record->{line_amount} = $sub_record->{wholesale_price} * $sub_record->{quantity};

        # strip out restricted chars
        $sub_record->{purchase_order_number} =~ s/[,\'\"\r\n]//g;
        $sub_record->{supplier_name} =~ s/[,\'\"\r\n]//g;
       
        print $fh "$sub_record->{identifier}~";
        print $fh "$record->{date}~";
        print $fh "~";
        print $fh "$sub_record->{supplier_name}~";
        print $fh "$sub_record->{currency}~";
        print $fh "$sub_record->{supplier_code}~";
        print $fh "$sub_record->{line_amount}~";
        print $fh "$sub_record->{quantity}~";
        print $fh "$sub_record->{legacy_sku}~";
        print $fh "$sub_record->{designer_id}~";
        print $fh "$sub_record->{season_id}~";
        print $fh "$sub_record->{country_of_origin}~";
        print $fh "~";
        print $fh "$sub_record->{type}~";
        print $fh "~";
        print $fh "$sub_record->{purchase_order_number}~";
        print $fh "~";
        print $fh "~";
        print $fh "1";
        print $fh "\r\n";
    }
}

close $fh;


$dbh->disconnect();

