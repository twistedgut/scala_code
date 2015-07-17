#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw ( read_handle us_handle );
use XTracker::Database::Invoice qw( get_invoice_country_info );

# hash of designers to exclude from feed
my %designer_exclusion = (
    'Mulberry' => 1,
);

### Linkshare account numbers for INTL and AM
my $intl_acc_number = "24448";
my $am_acc_number = "24449";

### db handles
my $dbh = read_handle();
my $dbh_us = us_handle();

my $uk_tax  = get_invoice_country_info( $dbh, 'United Kingdom' );
my $vat_rate= 1 + $uk_tax->{rate};

### db query to get date in correct formats
my $dt_qry = "select to_char(current_timestamp, 'YYYYMMDD') as short_date, to_char(current_timestamp, 'YYYY-MM-DD/HH24:MI:SS') as long_date";
my $dt_sth = $dbh->prepare($dt_qry);
$dt_sth->execute();
my $row = $dt_sth->fetchrow_hashref();

my $short_date = $row->{short_date};
my $long_date = $row->{long_date};

### get all exchange rates for conversions later
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

print "Got Exchange Rates...\n";

### get INTL and AM markdowns
my %intl_markdowns = ();
my %am_markdowns = ();

my $saleqry = "select product_id, percentage from price_adjustment where exported = true order by date_start asc";

my $intl_salesth = $dbh->prepare($saleqry);
$intl_salesth->execute();

while ( my $item = $intl_salesth->fetchrow_hashref() ) {
    $intl_markdowns{$$item{product_id}} = $$item{percentage};
}

print "Got INTL Markdowns...\n";

my $am_salesth = $dbh_us->prepare($saleqry);
$am_salesth->execute();

while ( my $item = $am_salesth->fetchrow_hashref() ) {
    $am_markdowns{$$item{product_id}} = $$item{percentage};
}

print "Got AM Markdowns...\n";

### set up product data query
my $prod_qry = "
select p.id, pd.currency_id, pd.price, pa.name, pa.short_description, pa.long_description, pa.keywords, d.designer, pt.product_type, p.visible
from product p, price_default pd, product_attribute pa, designer d, product_type pt
where p.live = true
and p.visible = true
and p.id = pd.product_id
and p.id = pa.product_id
and p.designer_id = d.id
and p.product_type_id = pt.id
";


##############################
### GENERATE INTL FILE
##############################

open (my $INTL_OUT,">","/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/".$intl_acc_number."_nmerchandis".$short_date.".txt") || warn "Cannot open output file: $!";

print $INTL_OUT "HDR|$intl_acc_number|NETAPORTER|$long_date\n";

my $intl_prod_sth = $dbh->prepare($prod_qry);
$intl_prod_sth->execute();

my $record_count = 0;

while (my $row = $intl_prod_sth->fetchrow_hashref) {

    my $retail_price = d2(($$row{price} * $vat_rate) * $exchange_rates{$$row{currency_id}}{1} );

    my $sale_price = "";

    my $discount = "";
    my $discount_type = "";

    if ($intl_markdowns{$$row{id}}) {

        $sale_price = d2( $retail_price * ((100 - $intl_markdowns{$$row{id}}) / 100) );
        $discount = $intl_markdowns{$$row{id}};
        $discount_type = "percentage";
    }

    my $keywords = $$row{keywords};
    $keywords =~ s/\s+/~/g;

    if ($$row{designer} =~ m/^Chlo/) {
        $$row{designer} = "Chloe";
    }

    if ( !$designer_exclusion{$$row{designer}} ) {

        print $INTL_OUT "$$row{id}|$$row{designer} $$row{name}|$$row{id}|$$row{product_type}||http://www.net-a-porter.com/intl/product/$$row{id}?cm_mmc=LinkshareUK-_-ProductFeed-_-$$row{designer}-_-$$row{product_type}|http://www.net-a-porter.com/pws/images/product/$$row{id}/large/index.jpg||$$row{short_description}|$$row{long_description}|$discount|$discount_type|$sale_price|$retail_price|||$$row{designer}|10|N|$keywords|Y|||||||Y|Y|Y|GBP|\n";

        $record_count++;
    }
}

print $INTL_OUT "TRL|$record_count\n";

close($INTL_OUT);

print "Generated INTL file...\n";

##############################
### GENERATE AM FILE
##############################

open (my $AM_OUT,">","/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/".$am_acc_number."_nmerchandis".$short_date.".txt") || warn "Cannot open output file: $!";

print $AM_OUT "HDR|$am_acc_number|NETAPORTER|$long_date\n";

my $am_prod_sth = $dbh_us->prepare($prod_qry);
$am_prod_sth->execute();

$record_count = 0;

while (my $row = $am_prod_sth->fetchrow_hashref) {

    my $retail_price = d2($$row{price} * $exchange_rates{$$row{currency_id}}{2} );

    my $sale_price = "";

    my $discount = "";
    my $discount_type = "";

    if ($am_markdowns{$$row{id}}) {

        $sale_price = d2( $retail_price * ((100 - $am_markdowns{$$row{id}}) / 100) );
        $discount = $am_markdowns{$$row{id}};
        $discount_type = "percentage";
    }

    my $keywords = $$row{keywords};
    $keywords =~ s/\s+/~/g;

    if ($$row{designer} =~ m/^Chlo/) {
        $$row{designer} = "Chloe";
    }

    if ( !$designer_exclusion{$$row{designer}} ) {
        print $AM_OUT "$$row{id}|$$row{designer} $$row{name}|$$row{id}|$$row{product_type}||http://www.net-a-porter.com/am/product/$$row{id}?cm_mmc=LinkshareUS-_-ProductFeed-_-$$row{designer}-_-$$row{product_type}|http://www.net-a-porter.com/pws/images/product/$$row{id}/large/index.jpg||$$row{short_description}|$$row{long_description}|$discount|$discount_type|$sale_price|$retail_price|||$$row{designer}|10|N|$keywords|Y|||||||Y|Y|Y|USD|\n";

        $record_count++;
    }
}

print $AM_OUT "TRL|$record_count\n";

close($AM_OUT);

print "Generated AM file...\n";

print "Done\n";

sub d2 {
    my $val = shift;
    my $n = sprintf("%.2f", $val);
    return $n;
}


