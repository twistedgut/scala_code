#!/opt/xt/xt-perl/bin/perl -w
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
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
my %returns     = ();

my $to          = $dt->date;
my $from        = $dt->subtract( days => 1 )->date;

GetOptions(
    'outdir=s'      => \$outdir,
    'channel_id=s'  => \$channel_id,
);

die 'No output directory defined' if not defined $outdir;
die 'No channel id defined' if not defined $channel_id;

# get tax rates per country
my %tax_rates;
my $tax_qry = "select c.country, ctr.rate from country c, country_tax_rate ctr where c.id = ctr.country_id";
my $tax_sth = $dbh->prepare($tax_qry);
$tax_sth->execute();

while( my $row = $tax_sth->fetchrow_hashref() ){
        $tax_rates{ $row->{country} } = $row->{rate};
}

# open output file and write header record
open my $fhex, '>', '/var/data/xt_static/data/maxisun/'.$outdir.'/sgr-ex.csv' || die "Couldn't open output file: $!";
open my $fhre, '>', '/var/data/xt_static/data/maxisun/'.$outdir.'/sgr-re.csv' || die "Couldn't open output file: $!";
open my $fhsc, '>', '/var/data/xt_static/data/maxisun/'.$outdir.'/sgr-sc.csv' || die "Couldn't open output file: $!";

print $fhex "type~date~empty1~airway_bill~currency~value~quantity~sku~designer_id~season_id~country_code~empty2~empty3~tax_code~order_number~empty4~empty5~code\r\n";
print $fhre "type~date~empty1~airway_bill~currency~value~quantity~sku~designer_id~season_id~country_code~empty2~empty3~tax_code~order_number~empty4~empty5~code\r\n";
print $fhsc "type~date~empty1~airway_bill~currency~value~quantity~sku~designer_id~season_id~country_code~empty2~empty3~tax_code~order_number~empty4~empty5~code\r\n";


my $qry = "select ri.id, cp.psp_ref as basket_nr, o.basket_nr as old_basket, o.order_nr, s.return_airway_bill, s.shipment_type_id,
            p.legacy_sku, p.designer_id, p.season_id, oa.country, oa.county, ctry.code as country_code, ri.return_type_id,
            r.rma_number, ren.renumeration_type_id, reni.unit_price, reni.tax, reni.duty,
            to_char(min(rsl.date), 'DDMMYYYY') as return_date, cur.currency, ren.shipping, ren.misc_refund
                      from orders o left join orders.payment cp on o.id = cp.orders_id, link_orders__shipment los, shipment s, return_item ri, return r, renumeration
             ren, renumeration_item reni, variant v, product p, order_address oa, country ctry, 
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
                AND oa.country = ctry.country
                AND o.channel_id = ?
        group by ri.id, cp.psp_ref, o.basket_nr, o.order_nr, s.return_airway_bill, s.shipment_type_id,
        p.legacy_sku, p.designer_id, p.season_id, oa.country, oa.county, ctry.code, ri.return_type_id,
        r.rma_number, ren.renumeration_type_id, reni.unit_price, reni.tax, reni.duty,
        cur.currency, ren.shipping, ren.misc_refund";
my $sth = $dbh->prepare($qry);
$sth->execute($from, $to, $channel_id);

while( my $row = $sth->fetchrow_hashref() ){

    if ($row->{return_airway_bill} eq "none"){
        $row->{return_airway_bill} = "";
    }

    if (!$row->{basket_nr}){
        $row->{basket_nr} = $row->{old_basket};
    }

    my $date_field = $row->{return_date};

    # DC2 requires state field
    my $state = "0";

    if ($row->{country} eq "United States" && ($row->{shipment_type_id} == 2 || $row->{shipment_type_id} == 3) ){
        $state = $row->{county};
    }

    my $tax_rate = $tax_rates{ $row->{country} } || 0;

    # store credits
    if ($row->{renumeration_type_id} == 1){

        # shipping refund and charges if not previously reported
        if ( !$returns{ $row->{order_nr} } ){
            $returns{ $row->{order_nr} } = 1;

            if ( $row->{shipping} != 0 ){

                my $shipping_excl_tax = sprintf( "%.3f", ( $row->{shipping} / (1 + $tax_rate) ) );
                my $shipping_tax      = sprintf( "%.3f", ( $row->{shipping} - $shipping_excl_tax ) );

                print $fhsc "CUSTNO~$date_field~~$row->{return_airway_bill}~$row->{currency}~$shipping_excl_tax~1~0~0~0~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~4\r\n";

                if ( $shipping_tax > 0 ){
                    print $fhsc "CUSTNO~$date_field~~$row->{return_airway_bill}~$row->{currency}~$shipping_tax~1~0~0~0~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~2\r\n";
                }
            }
            if ( $row->{misc_refund} != 0 ){

                my $misc_refund_excl_tax = sprintf( "%.3f", ( $row->{misc_refund} / (1 + $tax_rate) ) );
                my $misc_refund_tax      = sprintf( "%.3f", ( $row->{misc_refund} - $misc_refund_excl_tax ) );

                print $fhsc "CUSTNO~$date_field~~$row->{return_airway_bill}~$row->{currency}~$misc_refund_excl_tax~1~0~0~0~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~4\r\n";

                if ( $misc_refund_tax < 0 ){
                    print $fhsc "CUSTNO~$date_field~~$row->{return_airway_bill}~$row->{currency}~$misc_refund_tax~1~0~0~0~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~2\r\n";
                }
            }
        }

        print $fhsc "CUSTNO~$date_field~~$row->{return_airway_bill}~$row->{currency}~$row->{unit_price}~1~$row->{legacy_sku}~$row->{designer_id}~$row->{season_id}~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~1\r\n";

        if ($row->{tax} > 0){
            print $fhsc "CUSTNO~$date_field~~$row->{return_airway_bill}~$row->{currency}~$row->{tax}~1~0~0~0~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~2\r\n";
        }

        if ($row->{duty} > 0){
            print $fhsc "CUSTNO~$date_field~~$row->{return_airway_bill}~$row->{currency}~$row->{duty}~1~0~0~0~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~3\r\n";
        }
    }
    # card refunds
    elsif($row->{renumeration_type_id} == 2){

        # shipping refund and charges if not previously reported
        if ( !$returns{ $row->{order_nr} } ){
            $returns{ $row->{order_nr} } = 1;

            if ( $row->{shipping} != 0 ){

                my $shipping_excl_tax = sprintf( "%.3f", ( $row->{shipping} / (1 + $tax_rate) ) );
                my $shipping_tax      = sprintf( "%.3f", ( $row->{shipping} - $shipping_excl_tax ) );

                print $fhre "CCARD~$date_field~~$row->{basket_nr}~$row->{currency}~$shipping_excl_tax~1~0~0~0~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~4\r\n";

                if ( $shipping_tax > 0 ){
                    print $fhre "CCARD~$date_field~~$row->{basket_nr}~$row->{currency}~$shipping_tax~1~0~0~0~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~2\r\n";
                }
            }
            if ( $row->{misc_refund} != 0 ){

                my $misc_refund_excl_tax = sprintf( "%.3f", ( $row->{misc_refund} / (1 + $tax_rate) ) );
                my $misc_refund_tax      = sprintf( "%.3f", ( $row->{misc_refund} - $misc_refund_excl_tax ) );

                print $fhre "CCARD~$date_field~~$row->{basket_nr}~$row->{currency}~$misc_refund_excl_tax~1~0~0~0~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~4\r\n";

                if ( $misc_refund_tax < 0 ){
                    print $fhre "CCARD~$date_field~~$row->{basket_nr}~$row->{currency}~$misc_refund_tax~1~0~0~0~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~2\r\n";
                }
            }
        }

        print $fhre "CCARD~$date_field~~$row->{basket_nr}~$row->{currency}~$row->{unit_price}~1~$row->{legacy_sku}~$row->{designer_id}~$row->{season_id}~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~1\r\n";

        if ($row->{tax} > 0){
            print $fhre "CCARD~$date_field~~$row->{basket_nr}~$row->{currency}~$row->{tax}~1~$row->{legacy_sku}~$row->{designer_id}~$row->{season_id}~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~2\r\n";
        }

        if ($row->{duty} > 0){
            print $fhre "CCARD~$date_field~~$row->{basket_nr}~$row->{currency}~$row->{tax}~1~$row->{legacy_sku}~$row->{designer_id}~$row->{season_id}~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~3\r\n";
        }

    }

}


$qry = "select ri.id, cp.psp_ref as basket_nr, o.basket_nr as old_basket, o.order_nr, s.shipment_type_id, s.return_airway_bill,
p.legacy_sku, p.designer_id, p.season_id, oa.country, oa.county, ctry.code as country_code,
r.rma_number, si.unit_price, si.tax, si.duty, to_char(rsl.date, 'DDMMYYYY') as
return_date, cur.currency
      from orders o left join orders.payment cp on o.id = cp.orders_id, link_orders__shipment los, shipment s, return_item ri, return r, shipment_item si, variant v, product p, order_address oa,
      return_item_status_log rsl, currency cur, country ctry
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
        and oa.country = ctry.country
        and o.channel_id = ?";


$sth = $dbh->prepare($qry);
$sth->execute($from, $to, $channel_id);

while( my $row = $sth->fetchrow_hashref() ){

    if ($row->{return_airway_bill} eq "none"){
        $row->{return_airway_bill} = "";
    }

    if (!$row->{basket_nr}){
        $row->{basket_nr} = $row->{old_basket};
    }

    my $date_field = $row->{return_date};

    # DC2 requires state field
    my $state = "0";

    if ($row->{country} eq "United States" && ($row->{shipment_type_id} == 2 || $row->{shipment_type_id} == 3) ){
        $state = $row->{county};
    }

    print $fhex "$row->{rma_number}~$date_field~~$row->{return_airway_bill}~$row->{currency}~$row->{unit_price}~1~$row->{legacy_sku}~$row->{designer_id}~$row->{season_id}~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~1\r\n";

    if ($row->{tax} > 0){
        print $fhex "$row->{rma_number}~$date_field~~$row->{return_airway_bill}~$row->{currency}~$row->{tax}~1~0~0~0~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~2\r\n";
    }

    if ($row->{duty} > 0){
        print $fhex "$row->{rma_number}~$date_field~~$row->{return_airway_bill}~$row->{currency}~$row->{duty}~1~0~0~0~$row->{country_code}~~$state~$row->{country_code}~$row->{order_nr}~~~3\r\n";
    }

}

close $fhre;
close $fhsc;
close $fhex;


$dbh->disconnect();



