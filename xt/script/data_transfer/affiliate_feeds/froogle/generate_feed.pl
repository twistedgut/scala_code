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

# get INTL and AM markdowns
my %markdowns = ();

my $saleqry = "select product_id, percentage from price_adjustment where current_timestamp between date_start and date_finish and exported = true order by date_start asc";

my $salesth = $dbh->prepare($saleqry);
$salesth->execute();

while ( my $item = $salesth->fetchrow_hashref() ) {
    $markdowns{intl}{$$item{product_id}} = $$item{percentage};
}

$salesth = $dbh_us->prepare($saleqry);
$salesth->execute();

while ( my $item = $salesth->fetchrow_hashref() ) {
    $markdowns{am}{$$item{product_id}} = $$item{percentage};
}

# NAP files
open (my $NAPINTL,'>',"/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/net_a_porter_gb.txt") || warn "Cannot open output file: $!";
open (my $NAPAM,'>',"/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/nap_test.txt") || warn "Cannot open output file: $!";

print $NAPINTL "description\tid\tlink\tprice\ttitle\tbrand\timage_link\tcolor\tcondition\tproduct_type\n";
print $NAPAM "description\tid\tlink\tprice\ttitle\tbrand\timage_link\tcolor\tcondition\tproduct_type\n";

# OUTNET files
open (my $OUTINTL,'>',"/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/outnet_intl.txt") || warn "Cannot open output file: $!";
open (my $OUTAM,'>',"/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/outnet_am.txt") || warn "Cannot open output file: $!";

print $OUTINTL "description\tid\tlink\tprice\ttitle\tbrand\timage_link\tcolor\tcondition\tproduct_type\n";
print $OUTAM "description\tid\tlink\tprice\ttitle\tbrand\timage_link\tcolor\tcondition\tproduct_type\n";

my $qry = "
select p.id, pd.currency_id, pd.price, pc.price as uk_rrp, pr.price as americas_rrp, pa.name, pa.long_description, d.designer, pt.product_type, cf.colour_filter
from product p 
 LEFT JOIN price_country pc ON p.id = pc.product_id AND pc.country_id = (select id from country where country = 'United Kingdom')
 LEFT JOIN price_region pr ON p.id = pr.product_id AND pr.region_id = (select id from region where region = 'Americas'), 
 product_channel pch, price_default pd, product_attribute pa, designer d, product_type pt, filter_colour_mapping fcm, colour_filter cf
where p.id = pch.product_id
and pch.channel_id = (select id from channel where name = ?)
and pch.live = true
and pch.visible = true
and p.id = pd.product_id
and p.id = pa.product_id
and p.designer_id = d.id
and p.product_type_id = pt.id
and p.colour_id = fcm.colour_id
and fcm.filter_colour_id = cf.id
";




# generate NAP INTL file
my $sth = $dbh->prepare($qry);

$sth->execute( 'NET-A-PORTER.COM' );

while (my $row = $sth->fetchrow_hashref) {

    my $uk_price = $row->{price} * $vat_rate;

    if ($row->{uk_rrp}) {
        $uk_price = $row->{uk_rrp};
    }

    if ($markdowns{intl}{$row->{id}}) {
        $uk_price = $uk_price * ((100 - $markdowns{intl}{$row->{id}}) / 100);
    }

    $uk_price = d2($uk_price);

    print $NAPINTL "$row->{long_description}\t$row->{id}\thttp://www.net-a-porter.com/intl/product/$row->{id}?cm_mmc=Datafeed-_-Froogle-_-UK-_-$row->{designer} $row->{name}\t$uk_price\t$row->{designer} $row->{name}\t$row->{designer}\thttp://www.net-a-porter.com/images/products/$row->{id}/$row->{id}_in_l.jpg\t$row->{colour_filter}\tnew\t$row->{product_type}\n";

}


# generate NAP AM file
$sth = $dbh_us->prepare($qry);

$sth->execute( 'NET-A-PORTER.COM' );

while(my $row = $sth->fetchrow_hashref){

    my $dollar_price = $row->{price};

    if ($row->{americas_rrp}) {
        $dollar_price = $row->{americas_rrp};
    }

    if ($markdowns{am}{$row->{id}}) {
        $dollar_price = $dollar_price * ((100 - $markdowns{am}{$row->{id}}) / 100);
    }

    $dollar_price = d2($dollar_price);

    print $NAPAM "$row->{long_description}\t$row->{id}\thttp://www.net-a-porter.com/am/product/$row->{id}?cm_mmc=Datafeed-_-Froogle-_-UK-_-$row->{designer} $row->{name}\t$dollar_price\t$row->{designer} $row->{name}\t$row->{designer}\thttp://www.net-a-porter.com/images/products/$row->{id}/$row->{id}_in_l.jpg\t$row->{colour_filter}\tnew\t$row->{product_type}\n";

}


# generate OUTNET INTL file
$sth = $dbh->prepare($qry);

$sth->execute( 'theOutnet.com' );

while (my $row = $sth->fetchrow_hashref) {

    my $uk_price = $row->{price} * $vat_rate;

    if ($row->{uk_rrp}) {
        $uk_price = $row->{uk_rrp};
    }

    if ($markdowns{intl}{$row->{id}}) {
        $uk_price = $uk_price * ((100 - $markdowns{intl}{$row->{id}}) / 100);
    }

    $uk_price = d2($uk_price);

    print $OUTINTL "$row->{long_description}\t$row->{id}\thttp://www.theoutnet.com/intl/product/$row->{id}?cm_mmc=ProductSearch-_-UK-_-$row->{product_type}-_-$row->{name}\t$uk_price\t$row->{designer} $row->{name}\t$row->{designer}\thttp://www.theoutnet.com/images/products/$row->{id}/$row->{id}_in_l.jpg\t$row->{colour_filter}\tnew\t$row->{product_type}\n";

}


# generate OUTNET AM file
$sth = $dbh_us->prepare($qry);

$sth->execute( 'theOutnet.com' );

while (my $row = $sth->fetchrow_hashref) {

    my $dollar_price = $row->{price};

    if ($row->{americas_rrp}) {
        $dollar_price = $row->{americas_rrp};
    }

    if ($markdowns{am}{$row->{id}}) {
        $dollar_price = $dollar_price * ((100 - $markdowns{am}{$row->{id}}) / 100);
    }

    $dollar_price = d2($dollar_price);

    print $OUTAM "$row->{long_description}\t$row->{id}\thttp://www.theoutnet.com/am/product/$row->{id}?cm_mmc=ProductSearch-_-US-_-$row->{product_type}-_-$row->{name}\t$dollar_price\t$row->{designer} $row->{name}\t$row->{designer}\thttp://www.theoutnet.com/images/products/$row->{id}/$row->{id}_in_l.jpg\t$row->{colour_filter}\tnew\t$row->{product_type}\n";

}

close($NAPINTL);
close($NAPAM);
close($OUTINTL);
close($OUTAM);

sub d2 {
    my $val = shift;
    my $n = sprintf("%.2f", $val);
    return $n;
}


