#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;
use Getopt::Long;
use DateTime;
use XTracker::Constants::FromDB qw( :shipment_item_status );

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
open my $fh, '>', '/var/data/xt_static/data/maxisun/'.$outdir.'/sge.csv' || die "Couldn't open output file: $!";
print $fh "reference~date~empty1~airway_bill~currency~value~quantity~sku~designer_id~season_id~country_code~empty2~empty3~tax_code~order_number~empty4~empty5~code\r\n";


my @orders   = ();
my %giftcert = ();
my %shipments = ();
my %tax_rates = ();
my %shipment_item = ();

my $qry = "select o.order_nr, o.id as orders_id, o.date, o.basket_nr, s.id as shipment_id, s.shipment_type_id, s.outward_airway_bill, s.shipping_charge, s.shipment_type_id, oa.country, oa.county, ctry.code as country_code, to_char(sisl.date, 'DDMMYYYY') as dispatch_date, r.rma_number, c.currency
            from orders o, link_orders__shipment los, shipment s, order_address oa, country ctry,
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
            and oa.country = ctry.country
            and o.channel_id = ?";

my $sth = $dbh->prepare($qry);
$sth->execute($from, $to, $channel_id);

while( my $row = $sth->fetchrow_hashref() ){
    $shipments{$row->{shipment_id}}         = $row;
    $shipments{$row->{shipment_id}}{tax}    = 0;
    $shipments{$row->{shipment_id}}{duty}   = 0;
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
$sth->execute($from, $to);

while( my $row = $sth->fetchrow_hashref() ){
    $shipment_item{$row->{shipment_id}}{$row->{id}} = $row;
    $shipments{$row->{shipment_id}}{tax}            += $row->{tax};
    $shipments{$row->{shipment_id}}{duty}           += $row->{duty};
}

$qry = "select c.country, ctr.rate
        from country c, country_tax_rate ctr
        where c.id = ctr.country_id";

$sth = $dbh->prepare($qry);
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ){
        $tax_rates{$row->{country}} = $row->{rate};
}


foreach my $shipment_id (keys %shipments){

    if ($shipments{$shipment_id}{order_nr}){

        my $tax_rate = $tax_rates{$shipments{$shipment_id}{country}} || 0;

        # DC2 requires state field
        my $state = "0";

        if ($shipments{$shipment_id}{country} eq "United States" && ($shipments{$shipment_id}{shipment_type_id} == 2 || $shipments{$shipment_id}{shipment_type_id} == 3) ){
            $state = $shipments{$shipment_id}{county};

            # default 4.375% tax rate for NY
            if ( $state eq "NY" ){
                $tax_rate = 0.07;     
            }
        }

        # write line for each product in order
        foreach my $itemid (keys %{$shipment_item{$shipment_id}}){
            print $fh "$shipments{$shipment_id}{rma_number}~$shipments{$shipment_id}{dispatch_date}~~$shipments{$shipment_id}{outward_airway_bill}~$shipments{$shipment_id}{currency}~$shipment_item{$shipment_id}{$itemid}{unit_price}~1~$shipment_item{$shipment_id}{$itemid}{legacy_sku}~$shipment_item{$shipment_id}{$itemid}{designer_id}~$shipment_item{$shipment_id}{$itemid}{season_id}~$shipments{$shipment_id}{country_code}~~$state~$shipments{$shipment_id}{country_code}~$shipments{$shipment_id}{order_nr}~~~1\r\n";
        }

        $shipments{$shipment_id}{shipping_excl_tax} = sprintf( "%.3f", ( $shipments{$shipment_id}{shipping_charge} / (1 + $tax_rate) ) );
        $shipments{$shipment_id}{shipping_tax}      = sprintf( "%.3f", ( $shipments{$shipment_id}{shipping_charge} - $shipments{$shipment_id}{shipping_excl_tax} ) );        

        # write line for shipping charge
        print $fh "$shipments{$shipment_id}{rma_number}~$shipments{$shipment_id}{dispatch_date}~~$shipments{$shipment_id}{outward_airway_bill}~$shipments{$shipment_id}{currency}~$shipments{$shipment_id}{shipping_excl_tax}~1~0~0~0~$shipments{$shipment_id}{country_code}~~$state~$shipments{$shipment_id}{country_code}~$shipments{$shipment_id}{order_nr}~~~2\r\n";

        # write line for shipping tax
        if ($shipments{$shipment_id}{shipping_tax} > 0) {
           print $fh "$shipments{$shipment_id}{rma_number}~$shipments{$shipment_id}{dispatch_date}~~$shipments{$shipment_id}{outward_airway_bill}~$shipments{$shipment_id}{currency}~$shipments{$shipment_id}{shipping_tax}~1~0~0~0~$shipments{$shipment_id}{country_code}~~$state~$shipments{$shipment_id}{country_code}~$shipments{$shipment_id}{order_nr}~~~3\r\n";       
        }
       
        # write line for total tax
        print $fh "$shipments{$shipment_id}{rma_number}~$shipments{$shipment_id}{dispatch_date}~~$shipments{$shipment_id}{outward_airway_bill}~$shipments{$shipment_id}{currency}~$shipments{$shipment_id}{tax}~1~0~0~0~$shipments{$shipment_id}{country_code}~~$state~$shipments{$shipment_id}{country_code}~$shipments{$shipment_id}{order_nr}~~~3\r\n";

        # write line for total duties     
        print $fh "$shipments{$shipment_id}{rma_number}~$shipments{$shipment_id}{dispatch_date}~~$shipments{$shipment_id}{outward_airway_bill}~$shipments{$shipment_id}{currency}~$shipments{$shipment_id}{duty}~1~0~0~0~$shipments{$shipment_id}{country_code}~~$state~$shipments{$shipment_id}{country_code}~$shipments{$shipment_id}{order_nr}~~~4\r\n";
   
    }
}

close $fh;


$dbh->disconnect();
