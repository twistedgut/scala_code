#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw ( get_database_handle );
use XTracker::Database::Invoice qw( get_invoice_country_info );

my $dbh = get_database_handle( { name => 'XTracker_DC1', type => 'readonly' } );
my $dbh_us = get_database_handle( { name => 'XTracker_DC2', type => 'readonly' } );

my $uk_tax  = get_invoice_country_info( $dbh, 'United Kingdom' );
my $vat_rate= 1 + $uk_tax->{rate};

my %avail_usa = ();

my $usaqry = "
 select product_id from product_channel where live = true and visible = true and channel_id = (select id from channel where name = 'NET-A-PORTER.COM')
";
my $usasth = $dbh_us->prepare($usaqry);
$usasth->execute();

while ( my $item = $usasth->fetchrow_hashref() ) {
    $avail_usa{$$item{product_id}} = 1;
}

my %exchange_rates = ();

my $subqry = "
 select source_currency, destination_currency, conversion_rate 
 from sales_conversion_rate 
 where current_timestamp > date_start
 order by date_start asc
";

my $substh = $dbh->prepare($subqry);
$substh->execute();

while ( my $item = $substh->fetchrow_hashref() ) {
    $exchange_rates{$$item{source_currency}}{$$item{destination_currency}} = $$item{conversion_rate};
}

my %markdowns = ();

my $saleqry = "
 select product_id, percentage from price_adjustment where current_timestamp between date_start and date_finish and exported = true order by date_start asc
";

my $salesth = $dbh->prepare($saleqry);
$salesth->execute();

while ( my $item = $salesth->fetchrow_hashref() ) {
    $markdowns{$$item{product_id}} = $$item{percentage};
}



open (my $OUT,'>',"/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/affiliate_feed.csv") || warn "Cannot open output file: $!";

print $OUT "Language|Product ID|Product Name|Category|Manufacturer/Brand Name|Description|Deep Link|Image URL|Price|UK|US\n";

my $qry = "
select p.id, pd.currency_id, pd.price, pc.price as us_price, pr.currency_id as region_currency_id, pr.price as region_price, pa.name, pa.long_description, d.designer, pt.product_type
from product p LEFT JOIN price_country pc ON p.id = pc.product_id AND pc.country_id = 88 LEFT JOIN price_region pr ON p.id = pr.product_id AND pr.region_id = 1, product_channel pch, price_default pd, product_attribute pa, designer d, product_type pt
where p.id = pch.product_id
and pch.channel_id = (select id from channel where name = 'NET-A-PORTER.COM')
and pch.live = true
and pch.visible = true
and p.id = pd.product_id
and p.id = pa.product_id
and p.designer_id = d.id
and p.product_type_id = pt.id
";

my $sth = $dbh->prepare($qry);

$sth->execute();

while (my $row = $sth->fetchrow_hashref) {

    my $uk_price = $$row{price};

    if ($$row{currency_id} != 1) {
        $uk_price = $uk_price * $exchange_rates{$$row{currency_id}}{1};
    }

    if ($markdowns{$$row{id}}) {
        $uk_price = $uk_price * ((100 - $markdowns{$$row{id}}) / 100);
    }

    $uk_price = d2($uk_price * $vat_rate);

    if ($$row{designer} ne "Jimmy Choo") {
        print $OUT "uk|$$row{id}|$$row{name}|$$row{product_type}|$$row{designer}|$$row{long_description}|http://www.net-a-porter.com/product/$$row{id}?cm_mmc=Affiliate+Window*!!!sitename!!!*!!!sitename!!!*$$row{designer} $$row{name}&linkid=!!!linkid!!!&gid=!!!gid!!!&sitename=!!!sitename!!!&aid=!!!id!!!|http://www.net-a-porter.com/images/products/$$row{id}/$$row{id}_in_l.jpg|$uk_price|";

        print $OUT "YES|";

        if ($avail_usa{$$row{id}}) {
            print $OUT "YES";
        }
        else {
            print $OUT "NO";
        }

        print $OUT "\n";
    }
}

close($OUT);

sub d2 {
        my $val = shift;
        my $n = sprintf("%.2f", $val);
        return $n;
}


