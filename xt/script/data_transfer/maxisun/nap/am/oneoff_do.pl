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

$start = '2008-01-01';
$end = '2009-01-30';

my $qry = "select po.purchase_order_number, po.id, to_char(po.date, 'DDMMYYYY') as date, po.description, p.legacy_sku, d.designer,
                  s.season, sa.legacy_countryoforigin, sum(soi.quantity) as quantity_ordered,
                  min(soi.status_id) as status, pri.wholesale_price, cur.currency,
                  p.style_number, p.designer_id, p.season_id, sup.code as supplier_code
          from purchase_order po, variant v, product p, season s, price_purchase pri, currency cur,
                 shipping_attribute sa, stock_order so, stock_order_item soi, designer d, legacy_designer_supplier lds,
               supplier sup
          where po.date between ? and ?
          and so.purchase_order_id = po.id
          and so.id > 44599
          and po.type_id != 0
          and po.type_id < 3
          and soi.stock_order_id = so.id
          and soi.variant_id = v.id
          and v.product_id = p.id
          and sa.product_id = p.id
          and pri.product_id = p.id
          and pri.wholesale_currency_id = cur.id
          and p.season_id = s.id
          and p.designer_id = d.id
          and d.id = lds.designer_id
          and lds.supplier_id = sup.id
          --and p.season_id > 17
          group by po.purchase_order_number, po.id, po.date, po.description, p.legacy_sku, d.designer,
                   s.season, sa.legacy_countryoforigin, soi.status_id, pri.wholesale_price, cur.currency, p.style_number,
                   p.designer_id, p.season_id, sup.code";

my $sth = $dbh->prepare($qry);
$sth->execute($start, $end);

while( my $row = $sth->fetchrow_hashref() ){

    my $status;
    $row->{status} == 4 ? $status = 1 : $status = 0;

    $row->{description} =~ s/\r//g;
    $row->{description} =~ s/\n//g;
    $row->{description} =~ s/'//g;
    $row->{description} =~ s/&//g;
    $row->{legacy_countryoforigin} =~ s/\r//g;
        $row->{legacy_countryoforigin} =~ s/\n//g;
        $row->{legacy_countryoforigin} =~ s/'//g;
        $row->{legacy_countryoforigin} =~ s/&//g;

    push @purchase_order, { pon         => $row->{purchase_order_number},
                            po_id         => $row->{id},
                            description => $row->{description},
                            date        => $row->{date},
                            currency    => $row->{currency},
                            amount      => $row->{wholesale_price} * $row->{quantity_ordered},
                            sku          => $row->{legacy_sku},
                            designer    => $row->{designer},
                            designer_id => $row->{designer_id},
                            season      => $row->{season},
                            season_id   => $row->{season_id},
                            country     => $row->{legacy_countryoforigin},
                            quantity    => $row->{quantity_ordered},
                            status      => $status,
                            style_nr    => $row->{style_number},
                            supplier    => $row->{supplier_code},
                            };
}

$dbh->disconnect();

open my $fh, ">", "/opt/xt/deploy/xtracker/script/data_transfer/maxisun/am/do.csv" || die "Couldn't open file: $!";

foreach my $record ( @purchase_order ){

   my $po = substr $record->{pon}, -15, 15;

   $record->{supplier} =~ s/,//g;

   print $fh "$record->{pon}~";
   print $fh "$record->{date}~";
   print $fh "~";
   print $fh "$record->{style_nr}~";
   print $fh "$record->{currency}~";
   print $fh "$record->{supplier}~";
   print $fh "$record->{amount}~";
   print $fh "$record->{quantity}~";
   print $fh "$record->{sku}~";
   print $fh "$record->{designer_id}~";
   print $fh "$record->{season_id}~";
   print $fh "$record->{country}~";
   print $fh "~";
   print $fh "~";
   print $fh "~";
   print $fh "$po~";
   print $fh "~";
   print $fh "";
   print $fh "\r\n";
}

close $fh;




