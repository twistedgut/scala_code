#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database 'read_handle';

my $dbh = read_handle();

my @purchase_order = ();

my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst)=localtime(time);
$month++;
$year = $year+1900;

my $start = ((localtime(time-86400))[5] + 1900)."-".((localtime(time-86400))[4] + 1)."-".((localtime(time-86400))[3]);
my $end = $year."-".$month."-".$day;

my $qry = " 
select distinct del.id as delivery_id, to_char(del.date, 'DDMMYYYY') as date, 'none' as description, pri.wholesale_price, cur.currency, p.legacy_sku, d.designer, s.season, sa.legacy_countryoforigin as countryoforigin, po.purchase_order_number, po.type_id, p.style_number, p.designer_id, p.season_id, po.id as purchase_order_id, sup.code, sup.description as sup_description
from purchase_order po, stock_order so, stock_order_item soi, delivery del, log_delivery ld, product p, season s, price_purchase pri, currency cur, designer d, product_attribute att, variant v, legacy_designer_supplier lds, supplier sup, shipping_attribute sa, link_delivery__stock_order ld_so
where ld.date between ? and ? 
and ld.delivery_action_id = 2 
and ld.delivery_id = del.id 
and del.status_id > 1 
and (po.type_id < 3 OR po.type_id is null) 
and po.type_id != 0  
and po.channel_id = 2  
and po.id = so.purchase_order_id 
and soi.stock_order_id = so.id 
and so.id = ld_so.stock_order_id 
and del.id = ld_so.delivery_id 
and soi.variant_id = v.id 
and p.id = v.product_id 
and pri.product_id = p.id 
and pri.wholesale_currency_id = cur.id 
and p.id = att.product_id 
and p.season_id = s.id 
and p.designer_id = d.id 
and d.id = lds.designer_id 
and lds.supplier_id = sup.id 
and p.id = sa.product_id 
group by del.id, del.date, pri.wholesale_price, cur.currency, p.legacy_sku, d.designer, s.season, sa.legacy_countryoforigin, po.purchase_order_number, p.style_number, p.designer_id, p.season_id, po.id, sup.code, sup.description, po.type_id";

my $sth = $dbh->prepare($qry);
$sth->execute($start, $end);

my $qry_quant = 'select sum(quantity) from delivery_item where delivery_id = ?';
my $sth_quant = $dbh->prepare($qry_quant);

while( my $row = $sth->fetchrow_hashref() ){

    my $type = 1;

    $row->{description} =~ s/\r//g;
    $row->{description} =~ s/\n//g;
    $row->{description} =~ s/\t//g;
    $row->{description} =~ s/'//g;
    $row->{description} =~ s/&//g;
    $row->{countryoforigin} =~ s/\r//g;
    $row->{countryoforigin} =~ s/\n//g;
    $row->{countryoforigin} =~ s/\t//g;
    $row->{countryoforigin} =~ s/'//g;
    $row->{countryoforigin} =~ s/&//g;
    $row->{sup_description} =~ s/\r//g;
    $row->{sup_description} =~ s/\n//g;
    $row->{sup_description} =~ s/\t//g;
    $row->{sup_description} =~ s/'//g;
    $row->{sup_description} =~ s/&//g;
    $row->{designer} =~ s/'//g;

    push @purchase_order, { arrival_id      => $row->{delivery_id},
                            date            => substr( $row->{date}, 0, 10), 
                            description     => $row->{description}, 
                            wholesale       => $row->{wholesale_price},   
                            currency        => $row->{currency}, 
                            sku             => $row->{legacy_sku},   
                            designer        => $row->{designer},   
                            designer_id     => $row->{designer_id},
                            season          => $row->{season},   
                            season_id       => $row->{season_id},
                            country         => $row->{countryoforigin},   
                            pon             => $row->{purchase_order_number}, 
                            po_id           => $row->{po_id}, 
                            type            => $type,
                            style_nr        => $row->{style_number},
                            supplier_code   => $row->{code},
                            supplier        => $row->{sup_description},
                          };
}



open my $fh, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/am/csv/dg.csv" || die "Couldn't open file: $!";

foreach my $record ( @purchase_order ){

    $sth_quant->execute($record->{arrival_id});

    my $total_quantity = undef;
    $sth_quant->execute();
    $sth_quant->bind_columns( \$total_quantity );
    $sth_quant->fetch();
    $sth_quant->finish();

    my $amount = $record->{wholesale} * $total_quantity;

   my $po = substr $record->{pon}, -15, 15;

    $record->{supplier} =~ s/,//g;

   print $fh "$record->{arrival_id}~";
   print $fh "$record->{date}~";
   print $fh "~";
   print $fh "$record->{supplier}~";
   print $fh "$record->{currency}~";
   print $fh "$record->{supplier_code}~";
   print $fh "$amount~";
   print $fh "$total_quantity~";
   print $fh "$record->{sku}~";
   print $fh "$record->{designer_id}~";
   print $fh "$record->{season_id}~";
   print $fh "$record->{country}~";
   print $fh "~";
   print $fh "~";
   print $fh "~";
   print $fh "$po~";
   print $fh "~";
   print $fh "~";
   print $fh "$record->{type}";
   print $fh "\r\n";
}

$dbh->disconnect();
close $fh;



