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
open my $fh, '>', '/var/data/xt_static/data/maxisun/'.$outdir.'/do.csv' || die "Couldn't open output file: $!";
print $fh "reference~date~empty1~style_nr~currency~supplier_code~value~quantity~sku~designer_id~season_id~country_code~empty2~empty3~empty4~purchase_order_number~empty5~empty6\r\n";


my @purchase_order = ();

my $qry = "select po.purchase_order_number, po.id, to_char(po.date, 'DDMMYYYY') as date, po.description, p.legacy_sku, d.designer, 
                  s.season, ctry.code as country_code, sum(soi.quantity) as quantity_ordered, 
                  min(soi.status_id) as status, pri.wholesale_price,
                  cur.currency, 
                  p.style_number, p.designer_id, p.season_id, sup.code as supplier_code
          from purchase_order po, variant v, product p, season s,
          price_purchase pri, currency cur,
                 shipping_attribute sa LEFT JOIN country ctry ON sa.country_id = ctry.id, stock_order so, stock_order_item soi, designer d, legacy_designer_supplier lds, 
               supplier sup
          where po.date between ? and ?
          and so.purchase_order_id = po.id
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
          and p.season_id > 17
          and po.channel_id = ?
          group by po.purchase_order_number, po.id, po.date, po.description, p.legacy_sku, d.designer, 
                   s.season, ctry.code, soi.status_id,
                   pri.wholesale_price, cur.currency, p.style_number, 
                   p.designer_id, p.season_id, sup.code";

my $sth = $dbh->prepare($qry);
$sth->execute($from, $to, $channel_id);

while( my $row = $sth->fetchrow_hashref() ){

    my $status;
    $row->{status} == 4 ? $status = 1 : $status = 0;

    $row->{description} =~ s/\r//g;
    $row->{description} =~ s/\n//g;
    $row->{description} =~ s/'//g;
    $row->{description} =~ s/"//g;

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
                            country_code => $row->{country_code},   
                            quantity    => $row->{quantity_ordered},   
                            status      => $status,
                            style_nr    => $row->{style_number},   
                            supplier    => $row->{supplier_code},   
                        };
}

$dbh->disconnect();


foreach my $record ( @purchase_order ){

    my $po = substr $record->{pon}, -15, 15;
    $record->{supplier} =~ s/,//g;

    print $fh "$record->{pon}~$record->{date}~~$record->{style_nr}~$record->{currency}~$record->{supplier}~$record->{amount}~$record->{quantity}~$record->{sku}~$record->{designer_id}~$record->{season_id}~$record->{country_code}~~~~$po~~\r\n";
}

close $fh;




