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
open my $fh, '>', '/var/data/xt_static/data/maxisun/'.$outdir.'/dgc.csv' || die "Couldn't open output file: $!";
print $fh "reference~date~empty1~supplier~currency~supplier_code~value~quantity~sku~designer_id~season_id~country_code~empty2~empty3~empty4~purchase_order_number~empty5~empty6~type\r\n";


my @purchase_order = ();

my $qry = " 
select distinct del.id as delivery_id, to_char(del.date, 'DDMMYYYY') as date, 'none' as description, pri.wholesale_price, cur.currency, p.legacy_sku, d.designer, s.season, ctry.code as countryoforigin, po.purchase_order_number, po.type_id, p.style_number, p.designer_id, p.season_id, po.id as purchase_order_id, sup.code, sup.description as sup_description 
from purchase_order po, stock_order so, stock_order_item soi, delivery del, log_delivery ld, product p, season s, price_purchase pri, currency cur, designer d, product_attribute att, variant v, legacy_designer_supplier lds, supplier sup, shipping_attribute sa LEFT JOIN country ctry ON sa.country_id = ctry.id, link_delivery__stock_order ld_so 
where ld.date between ? and ?
and ld.delivery_action_id = 7 
and ld.delivery_id = del.id 
and del.cancel is true 
and del.id in (select delivery_id from log_delivery where delivery_action_id = 2)
and po.type_id in (1,2)
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
and po.channel_id = ?
group by del.id, del.date, pri.wholesale_price, cur.currency, p.legacy_sku, d.designer, s.season, ctry.code, po.purchase_order_number, p.style_number, p.designer_id, p.season_id, po.id, sup.code, sup.description, po.type_id
";

my $sth = $dbh->prepare($qry);
$sth->execute($from, $to, $channel_id);

my $qry_quant = 'select sum(quantity) from delivery_item where delivery_id = ?';
my $sth_quant = $dbh->prepare($qry_quant);

while( my $row = $sth->fetchrow_hashref() ){

    my $type = 1;

    if ($row->{type_id} == 3){
        $type = 2;
    }

    $row->{description} =~ s/\r//g;
    $row->{description} =~ s/\n//g;
    $row->{description} =~ s/\t//g;
    $row->{sup_description} =~ s/\r//g;
    $row->{sup_description} =~ s/\n//g;
    $row->{sup_description} =~ s/\t//g;

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
                            country_code    => $row->{countryoforigin},   
                            pon             => $row->{purchase_order_number}, 
                            po_id           => $row->{po_id}, 
                            type            => $type,
                            style_nr        => $row->{style_number},
                            supplier_code   => $row->{code},
                            supplier        => $row->{sup_description},
                          };
}


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

    if (!$record->{country_code}) {
        $record->{country_code} = '';
    }

    print $fh "$record->{arrival_id}c~$record->{date}~~$record->{supplier}~$record->{currency}~$record->{supplier_code}~$amount~$total_quantity~$record->{sku}~$record->{designer_id}~$record->{season_id}~$record->{country_code}~~~~$po~~~$record->{type}\r\n";
}


close $fh;

$dbh->disconnect();


