#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database 'read_handle';
use XTracker::Constants::FromDB qw( :shipment_item_status );

my $dbh = read_handle();

my @orders   = ();
my %giftcert = ();

my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst)=localtime(time); $month++; $year = $year+1900;

my $start = ((localtime(time-86400))[5] + 1900)."-".((localtime(time-86400))[4] + 1)."-".((localtime(time-86400))[3]);
my $end = $year."-".$month."-".$day;

my %tax_rates = ();
my %shipments = ();
my %shipment_item = ();

my $qry = "select o.order_nr, o.id as orders_id, o.date, o.basket_nr, s.id as
shipment_id, s.outward_airway_bill, s.shipping_charge, s.shipment_type_id,
oa.country, to_char(sisl.date, 'DDMMYYYY') as dispatch_date, r.rma_number, c.currency 
    from orders o, link_orders__shipment los, shipment s, order_address oa,
    shipment_item si, shipment_item_status_log sisl, return r, currency c 
    where sisl.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED
    and sisl.date between ? and ?
    and sisl.shipment_item_id = si.id
    and si.shipment_id = s.id
    and s.shipment_class_id = 3
    and s.id = los.shipment_id
    and los.orders_id = o.id
    and s.shipment_address_id = oa.id
    and s.id = r.exchange_shipment_id
    and o.currency_id = c.id
    and o.channel_id = 1";

my $sth = $dbh->prepare($qry);
$sth->execute($start, $end);

while( my $row = $sth->fetchrow_hashref() ){
    $shipments{$row->{shipment_id}} = $row;
    $shipments{$row->{shipment_id}}{tax} = 0;
    $shipments{$row->{shipment_id}}{duty} = 0;
}

$qry = "select si.id, si.shipment_id, si.unit_price, si.tax, si.duty, si.variant_id, p.legacy_sku, p.style_number, p.designer_id, d.designer, p.season_id, s.season 
    from shipment_item_status_log sisl, shipment_item si, variant v, product p, designer d, season s
    where sisl.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED
    and sisl.date between ? and ?
    and sisl.shipment_item_id = si.id
    and si.variant_id = v.id
    and v.product_id = p.id
    and p.designer_id = d.id
    and p.season_id = s.id";

$sth = $dbh->prepare($qry);
$sth->execute($start, $end);

while( my $row = $sth->fetchrow_hashref() ){
    $shipment_item{$row->{shipment_id}}{$row->{id}} = $row;

    $shipments{$row->{shipment_id}}{tax} += $row->{tax};
    $shipments{$row->{shipment_id}}{duty} += $row->{duty};
}


$qry = "select c.country, ctr.rate
    from country c, country_tax_rate ctr
    where c.id = ctr.country_id";

$sth = $dbh->prepare($qry);
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ){
    $tax_rates{$row->{country}} = $row->{rate};
}

open my $fh, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/intl/csv/sge.csv" || die "Couldn't open file: $!";


foreach my $shipment_id (keys %shipments){

    if (!$tax_rates{$shipments{$shipment_id}{country}}){
        $tax_rates{$shipments{$shipment_id}{country}} = 0;
    }

    if ($shipments{$shipment_id}{order_nr}) {

        foreach my $itemid (keys %{$shipment_item{$shipment_id}}) {

            if ($shipment_item{$shipment_id}{$itemid}{legacy_sku} eq "NP04") {
                print $fh "$shipments{$shipment_id}{rma_number}~";
                print $fh "$shipments{$shipment_id}{dispatch_date}~";
                print $fh "~";
                print $fh "$shipments{$shipment_id}{outward_airway_bill}~";
                print $fh "$shipments{$shipment_id}{currency}~";
                print $fh "$shipment_item{$shipment_id}{$itemid}{unit_price}~";
                print $fh "1~";
                print $fh "0~";
                print $fh "0~";
                print $fh "0~";
                print $fh "$shipments{$shipment_id}{country}~";
                print $fh "~";
                print $fh "~";
                print $fh "$tax_rates{$shipments{$shipment_id}{country}}~";
                print $fh "$shipments{$shipment_id}{order_nr}~";
                print $fh "~";
                print $fh "~";
                print $fh "6";
                print $fh "\r\n";

            }
            else {
                print $fh "$shipments{$shipment_id}{rma_number}~";
                print $fh "$shipments{$shipment_id}{dispatch_date}~";
                print $fh "~";
                print $fh "$shipments{$shipment_id}{outward_airway_bill}~";
                print $fh "$shipments{$shipment_id}{currency}~";
                print $fh "$shipment_item{$shipment_id}{$itemid}{unit_price}~";
                print $fh "1~";
                print $fh "$shipment_item{$shipment_id}{$itemid}{legacy_sku}~";
                print $fh "$shipment_item{$shipment_id}{$itemid}{designer_id}~";
                print $fh "$shipment_item{$shipment_id}{$itemid}{season_id}~";
                print $fh "$shipments{$shipment_id}{country}~";
                print $fh "~";
                print $fh "~";
                print $fh "$tax_rates{$shipments{$shipment_id}{country}}~";
                print $fh "$shipments{$shipment_id}{order_nr}~";
                print $fh "~";
                print $fh "~";
                print $fh "1";
                print $fh "\r\n";
            }
        }

        $shipments{$shipment_id}{shipping_excl_tax} = d3( $shipments{$shipment_id}{shipping_charge} / (1 + $tax_rates{$shipments{$shipment_id}{country}}) );
        $shipments{$shipment_id}{shipping_tax} = d3( $shipments{$shipment_id}{shipping_charge} - $shipments{$shipment_id}{shipping_excl_tax} );

        print $fh "$shipments{$shipment_id}{rma_number}~";
        print $fh "$shipments{$shipment_id}{dispatch_date}~";
        print $fh "~";
        print $fh "$shipments{$shipment_id}{outward_airway_bill}~";
        print $fh "$shipments{$shipment_id}{currency}~";
        print $fh "$shipments{$shipment_id}{shipping_excl_tax}~";
        print $fh "1~";
        print $fh "0~";
        print $fh "0~";
        print $fh "0~";
        print $fh "$shipments{$shipment_id}{country}~";
        print $fh "~";
        print $fh "~";
        print $fh "$tax_rates{$shipments{$shipment_id}{country}}~";
        print $fh "$shipments{$shipment_id}{order_nr}~";
        print $fh "~";
        print $fh "~";
        print $fh "2";
        print $fh "\r\n";

        if ($shipments{$shipment_id}{shipping_tax} > 0) {
            print $fh "$shipments{$shipment_id}{rma_number}~";
            print $fh "$shipments{$shipment_id}{dispatch_date}~";
            print $fh "~";
            print $fh "$shipments{$shipment_id}{outward_airway_bill}~";
            print $fh "$shipments{$shipment_id}{currency}~";
            print $fh "$shipments{$shipment_id}{shipping_tax}~";
            print $fh "1~";
            print $fh "0~";
            print $fh "0~";
            print $fh "0~";
            print $fh "$shipments{$shipment_id}{country}~";
            print $fh "~";
            print $fh "~";
            print $fh "$tax_rates{$shipments{$shipment_id}{country}}~";
            print $fh "$shipments{$shipment_id}{order_nr}~";
            print $fh "~";
            print $fh "~";
            print $fh "3";
            print $fh "\r\n";
   
        }
   
        print $fh "$shipments{$shipment_id}{rma_number}~";
        print $fh "$shipments{$shipment_id}{dispatch_date}~";
        print $fh "~";
        print $fh "$shipments{$shipment_id}{outward_airway_bill}~";
        print $fh "$shipments{$shipment_id}{currency}~";
        print $fh "$shipments{$shipment_id}{tax}~";
        print $fh "1~";
        print $fh "0~";
        print $fh "0~";
        print $fh "0~";
        print $fh "$shipments{$shipment_id}{country}~";
        print $fh "~";
        print $fh "~";
        print $fh "$tax_rates{$shipments{$shipment_id}{country}}~";
        print $fh "$shipments{$shipment_id}{order_nr}~";
        print $fh "~";
        print $fh "~";
        print $fh "3";
        print $fh "\r\n";
   
        print $fh "$shipments{$shipment_id}{rma_number}~";
        print $fh "$shipments{$shipment_id}{dispatch_date}~";
        print $fh "~";
        print $fh "$shipments{$shipment_id}{outward_airway_bill}~";
        print $fh "$shipments{$shipment_id}{currency}~";
        print $fh "$shipments{$shipment_id}{duty}~";
        print $fh "1~";
        print $fh "0~";
        print $fh "0~";
        print $fh "0~";
        print $fh "$shipments{$shipment_id}{country}~";
        print $fh "~";
        print $fh "~";
        print $fh "$tax_rates{$shipments{$shipment_id}{country}}~";
        print $fh "$shipments{$shipment_id}{order_nr}~";
        print $fh "~";
        print $fh "~";
        print $fh "4";
        print $fh "\r\n";
   
    }
}

close $fh;

#}

$dbh->disconnect();



sub d3 {
    my $val = shift;
    my $n = sprintf( "%.3f", $val );
    return $n;
}
