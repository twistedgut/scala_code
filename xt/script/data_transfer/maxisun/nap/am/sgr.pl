#!/opt/xt/xt-perl/bin/perl -w
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database 'read_handle';

my $dbh = read_handle();

my @orders   = ();
my %giftcert = ();

my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst)=localtime(time); $month++; $year = $year+1900;

my $start = ((localtime(time-86400))[5] + 1900)."-".((localtime(time-86400))[4] + 1)."-".((localtime(time-86400))[3]);
my $end = $year."-".$month."-".$day;

print "$start";

my %tax_rates = ();
my $qry = "select c.country, ctr.rate
    from country c, country_tax_rate ctr
    where c.id = ctr.country_id";

my $sth = $dbh->prepare($qry);
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ){
    $tax_rates{$row->{country}} = $row->{rate};
}

$qry = "select ri.id, cp.psp_ref as basket_nr, o.basket_nr as old_basket, o.order_nr, s.return_airway_bill,
p.legacy_sku, p.designer_id, p.season_id, oa.country, oa.county, ri.return_type_id,
r.rma_number, ren.renumeration_type_id, reni.unit_price, reni.tax, reni.duty,
to_char(min(rsl.date), 'DDMMYYYY') as return_date, cur.currency
          from orders o left join orders.payment cp on o.id = cp.orders_id, link_orders__shipment los, shipment s, return_item ri, return r, renumeration
 ren, renumeration_item reni, variant v, product p, order_address oa,
      return_item_status_log rsl, currency cur
            where rsl.date between ? and ?
                and rsl.return_item_status_id = 2
                and rsl.return_item_id = ri.id
                and ri.return_id = r.id
                and r.shipment_id = s.id
                and s.id = los.shipment_id
                and los.orders_id = o.id
                and ri.variant_id = v.id
                and v.product_id = p.id
                and s.shipment_address_id = oa.id
                AND ri.shipment_item_id = reni.shipment_item_id
                AND reni.renumeration_id = ren.id
                AND ren.renumeration_class_id = 3
                AND ren.renumeration_status_id < 6
        AND o.currency_id = cur.id
        and o.channel_id = 2
        group by ri.id, cp.psp_ref, o.basket_nr, o.order_nr, s.return_airway_bill,
p.legacy_sku, p.designer_id, p.season_id, oa.country, oa.county, ri.return_type_id,
r.rma_number, ren.renumeration_type_id, reni.unit_price, reni.tax, reni.duty,
cur.currency
                ";

$sth = $dbh->prepare($qry);

$sth->execute($start, $end);

open my $fh1, ">",
"/var/data/xt_static/utilities/data_transfer/maxisun/am/csv/sgr-ex.csv" || die "Couldn't open file: $!";
open my $fh2, ">",
"/var/data/xt_static/utilities/data_transfer/maxisun/am/csv/sgr-re.csv" || die
"Couldn't open file: $!";
open my $fh3, ">",
"/var/data/xt_static/utilities/data_transfer/maxisun/am/csv/sgr-sc.csv" || die
"Couldn't open file: $!";

while( my $row = $sth->fetchrow_hashref() ){

    if ($row->{return_airway_bill} eq "none"){
        $row->{return_airway_bill} = "";
    }

    if (!$row->{basket_nr}){
        $row->{basket_nr} = $row->{old_basket};
    }

    if (!$tax_rates{$row->{country}}) {
        $tax_rates{$row->{country}} = 0;
    }

    my $state = "0";

    if ($row->{country} eq "United States"){
        $state = $row->{county};

        if ($state eq "NY"){
            $tax_rates{$row->{country}} = 0.07;
        }
        else {
            $tax_rates{$row->{country}} = 0;
        }
    }

    my $date_field = $row->{return_date};


    ### store credits
    if ($row->{renumeration_type_id} == 1){

        print $fh3 "CUSTNO~";
        print $fh3 "$date_field~";
        print $fh3 "~";
        print $fh3 "$row->{return_airway_bill}~";
        print $fh3 "$row->{currency}~";
        print $fh3 "$row->{unit_price}~";
        print $fh3 "1~";
        print $fh3 "$row->{legacy_sku}~";
        print $fh3 "$row->{designer_id}~";
        print $fh3 "$row->{season_id}~";
        print $fh3 "$row->{country}~";
        print $fh3 "~";
        print $fh3 "$state~";
        print $fh3 "$tax_rates{$row->{country}}~";
        print $fh3 "$row->{order_nr}~";
        print $fh3 "~";
        print $fh3 "~";
        print $fh3 "1";
        print $fh3 "\r\n";

        if ($row->{tax} > 0){
            print $fh3 "CUSTNO~";
            print $fh3 "$date_field~";
            print $fh3 "~";
            print $fh3 "$row->{return_airway_bill}~";
            print $fh3 "$row->{currency}~";
            print $fh3 "$row->{tax}~";
            print $fh3 "1~";
            print $fh3 "0~";
            print $fh3 "0~";
            print $fh3 "0~";
            print $fh3 "$row->{country}~";
            print $fh3 "~";
            print $fh3 "$state~";
            print $fh3 "$tax_rates{$row->{country}}~";
            print $fh3 "$row->{order_nr}~";
            print $fh3 "~";
            print $fh3 "~";
            print $fh3 "2";
            print $fh3 "\r\n";
        }

        if ($row->{duty} > 0){

            print $fh3 "CUSTNO~";
            print $fh3 "$date_field~";
            print $fh3 "~";
            print $fh3 "$row->{return_airway_bill}~";
            print $fh3 "$row->{currency}~";
            print $fh3 "$row->{duty}~";
            print $fh3 "1~";
            print $fh3 "0~";
            print $fh3 "0~";
            print $fh3 "0~";
            print $fh3 "$row->{country}~";
            print $fh3 "~";
            print $fh3 "$state~";
            print $fh3 "$tax_rates{$row->{country}}~";
            print $fh3 "$row->{order_nr}~";
            print $fh3 "~";
            print $fh3 "~";
            print $fh3 "3";
            print $fh3 "\r\n";

        }
    }
    ### card refunds
    elsif($row->{renumeration_type_id} == 2){

        print $fh2 "CCARD~";
        print $fh2 "$date_field~";
        print $fh2 "~";
        print $fh2 "$row->{basket_nr}~";
        print $fh2 "$row->{currency}~";
        print $fh2 "$row->{unit_price}~";
        print $fh2 "1~";
        print $fh2 "$row->{legacy_sku}~";
        print $fh2 "$row->{designer_id}~";
        print $fh2 "$row->{season_id}~";
        print $fh2 "$row->{country}~";
        print $fh2 "~";
        print $fh2 "$state~";
        print $fh2 "$tax_rates{$row->{country}}~";
        print $fh2 "$row->{order_nr}~";
        print $fh2 "~";
        print $fh2 "~";
        print $fh2 "1";
        print $fh2 "\r\n";

        if ($row->{tax} > 0) {
            print $fh2 "CCARD~";
            print $fh2 "$date_field~";
            print $fh2 "~";
            print $fh2 "$row->{basket_nr}~";
            print $fh2 "$row->{currency}~";
            print $fh2 "$row->{tax}~";
            print $fh2 "1~";
            print $fh2 "0~";
            print $fh2 "0~";
            print $fh2 "0~";
            print $fh2 "$row->{country}~";
            print $fh2 "~";
            print $fh2 "$state~";
            print $fh2 "$tax_rates{$row->{country}}~";
            print $fh2 "$row->{order_nr}~";
            print $fh2 "~";
            print $fh2 "~";
            print $fh2 "2";
            print $fh2 "\r\n";
        }

        if ($row->{duty} > 0) {

            print $fh2 "CCARD~";
            print $fh2 "$date_field~";
            print $fh2 "~";
            print $fh2 "$row->{basket_nr}~";
            print $fh2 "$row->{currency}~";
            print $fh2 "$row->{duty}~";
            print $fh2 "1~";
            print $fh2 "0~";
            print $fh2 "0~";
            print $fh2 "0~";
            print $fh2 "$row->{country}~";
            print $fh2 "~";
            print $fh2 "$state~";
            print $fh2 "$tax_rates{$row->{country}}~";
            print $fh2 "$row->{order_nr}~";
            print $fh2 "~";
            print $fh2 "~";
            print $fh2 "3";
            print $fh2 "\r\n";

        }

    }
    else {
    }

}


$qry = "select ri.id, cp.psp_ref as basket_nr, o.basket_nr as old_basket, o.order_nr, s.return_airway_bill,
p.legacy_sku, p.designer_id, p.season_id, oa.country, oa.county,
r.rma_number, si.unit_price, si.tax, si.duty, to_char(rsl.date, 'DDMMYYYY') as
return_date, cur.currency
      from orders o left join orders.payment cp on o.id = cp.orders_id, link_orders__shipment los, shipment s, return_item ri, return r, shipment_item si, variant v, product p, order_address oa,
      return_item_status_log rsl, currency cur            
        where rsl.date between ? and ?
        and rsl.return_item_status_id = 2
        and rsl.return_item_id = ri.id
        and ri.return_type_id = 2
        and ri.return_id = r.id
        and r.shipment_id = s.id
        and s.id = los.shipment_id
        and los.orders_id = o.id
        and ri.shipment_item_id = si.id
        and ri.variant_id = v.id
        and v.product_id = p.id
        and s.shipment_address_id = oa.id
        and o.currency_id = cur.id
        and o.channel_id = 2";


$sth = $dbh->prepare($qry);

$sth->execute($start, $end);

while ( my $row = $sth->fetchrow_hashref() ) {

    if ($row->{return_airway_bill} eq "none") {
        $row->{return_airway_bill} = "";
    }

    if (!$row->{basket_nr}) {
        $row->{basket_nr} = $row->{old_basket};
    }

    if (!$tax_rates{$row->{country}}) {
        $tax_rates{$row->{country}} = 0;
    }

    my $state = "0";

    if ($row->{country} eq "United States") {
        $state = $row->{county};

        if ($state eq "NY") {
            $tax_rates{$row->{country}} = 0.07;
        }
        else {
            $tax_rates{$row->{country}} = 0;
        }
    }

    my $date_field = $row->{return_date};

    print $fh1 "$row->{rma_number}~";
    print $fh1 "$date_field~";
    print $fh1 "~";
    print $fh1 "$row->{return_airway_bill}~";
    print $fh1 "$row->{currency}~";
    print $fh1 "$row->{unit_price}~";
    print $fh1 "1~";
    print $fh1 "$row->{legacy_sku}~";
    print $fh1 "$row->{designer_id}~";
    print $fh1 "$row->{season_id}~";
    print $fh1 "$row->{country}~";
    print $fh1 "~";
    print $fh1 "$state~";
    print $fh1 "$tax_rates{$row->{country}}~";
    print $fh1 "$row->{order_nr}~";
    print $fh1 "~";
    print $fh1 "~";
    print $fh1 "1";
    print $fh1 "\r\n";

    if ($row->{tax} > 0) {
        print $fh1 "$row->{rma_number}~";
        print $fh1 "$date_field~";
        print $fh1 "~";
        print $fh1 "$row->{return_airway_bill}~";
        print $fh1 "$row->{currency}~";
        print $fh1 "$row->{tax}~";
        print $fh1 "1~";
        print $fh1 "0~";
        print $fh1 "0~";
        print $fh1 "0~";
        print $fh1 "$row->{country}~";
        print $fh1 "~";
        print $fh1 "$state~";
        print $fh1 "$tax_rates{$row->{country}}~";
        print $fh1 "$row->{order_nr}~";
        print $fh1 "~";
        print $fh1 "~";
        print $fh1 "2";
        print $fh1 "\r\n";
    }

    if ($row->{duty} > 0) {

        print $fh1 "$row->{rma_number}~";
        print $fh1 "$date_field~";
        print $fh1 "~";
        print $fh1 "$row->{return_airway_bill}~";
        print $fh1 "$row->{currency}~";
        print $fh1 "$row->{duty}~";
        print $fh1 "1~";
        print $fh1 "0~";
        print $fh1 "0~";
        print $fh1 "0~";
        print $fh1 "$row->{country}~";
        print $fh1 "~";
        print $fh1 "$state~";
        print $fh1 "$tax_rates{$row->{country}}~";
        print $fh1 "$row->{order_nr}~";
        print $fh1 "~";
        print $fh1 "~";
        print $fh1 "3";
        print $fh1 "\r\n";

    }

}

close $fh1;
close $fh2;
close $fh3;


$dbh->disconnect();



