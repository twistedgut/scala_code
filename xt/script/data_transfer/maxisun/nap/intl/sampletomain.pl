#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;

my $dbh = read_handle();

my $start = '2009-02-01';
my $end = '2009-03-01';

my $qry = "select r.rma_number, to_char(rsl.date, 'DDMMYYYY') as return_date, p.legacy_sku, p.style_number, p.designer_id, p.season_id, c.country, sa.legacy_countryoforigin, pri.wholesale_price, curr.currency as wholesale_currency, sup.code
    from return_status_log rsl, return r, shipment s, shipment_item si, variant v, product p, legacy_designer_supplier lds, supplier sup, price_purchase pri, currency curr, shipping_attribute sa LEFT JOIN country c ON sa.country_id = c.id
    where rsl.date between ? and ?
    and rsl.return_status_id = 1
    and rsl.return_id = r.id
    and r.shipment_id = s.id
    and s.shipment_class_id = 7
    and s.id = si.shipment_id
    and si.variant_id = v.id
    and v.product_id = p.id
    and p.id = pri.product_id
    and pri.wholesale_currency_id = curr.id
    and p.id = sa.product_id
    and p.designer_id = lds.designer_id
    and lds.supplier_id = sup.id";

my $sth = $dbh->prepare($qry);
$sth->execute($start, $end);

open my $fh, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/intl/csv/SAMPLETOMAIN.csv" || die "Couldn't open file: $!";

while( my $row = $sth->fetchrow_hashref() ){

    if (!$row->{country}) {
        $row->{country} = $row->{legacy_countryoforigin};
    }

    print $fh "$row->{rma_number}~";
    print $fh "$row->{return_date}~";
    print $fh "~";
    print $fh "$row->{style_number}~";
    print $fh "$row->{wholesale_currency}~";
    print $fh "$row->{code}~";
    print $fh "$row->{wholesale_price}~";
    print $fh "1~";
    print $fh "$row->{legacy_sku}~";
    print $fh "$row->{designer_id}~";
    print $fh "$row->{season_id}~";
    print $fh "$row->{country}~";
    print $fh "~";
    print $fh "~";
    print $fh "~";
    print $fh "~";
    print $fh "~";
    print $fh "";
    print $fh "\r\n";

       
}

close $fh;

$dbh->disconnect();



sub d3 {
    my $val = shift;
    my $n = sprintf( "%.3f", $val );
    return $n;
}
