#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( get_database_handle );

my $dbh = get_database_handle( { name => 'XTracker_DC2', type => 'readonly' } );

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


open (my $OUT,">","/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/glamfeed.txt") || warn "Cannot open output file: $!";

print $OUT "ProductId\tProductName\tShortDescription\tProductURL\tImageURL\tCategory\tBrand\tPrice\tExtraImageURL1\tExtraImageURL2\tExtraImageURL3\n";

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

    my $dollar_price = 0;

    if ($$row{us_price}) {
        $dollar_price = $$row{us_price};
    } elsif ($$row{region_price}) {
        $dollar_price = $$row{region_price};

        if ($$row{region_currency_id} != 2) {    
            $dollar_price = $dollar_price * $exchange_rates{$$row{region_currency_id}}{2};
        }
    } else {
        $dollar_price = $$row{price};

        if ($$row{currency_id} != 2) {    
            $dollar_price = $dollar_price * $exchange_rates{$$row{currency_id}}{2};
        }
    }

    if ($markdowns{$$row{id}}) {
        $dollar_price = $dollar_price * ((100 - $markdowns{$$row{id}}) / 100);
    }

    $dollar_price = d2($dollar_price);

    print $OUT "$$row{id}\t$$row{designer} $$row{name}\t$$row{long_description}\thttp://www.net-a-porter.com/product/$$row{id}?cm_mmc=Datafeed-_-glam.com-_-glam.com-_-$$row{designer} $$row{name}\thttp://www.net-a-porter.com/images/products/$$row{id}/$$row{id}_in_l.jpg\t$$row{product_type}\t$$row{designer}\t$dollar_price\thttp://www.net-a-porter.com/images/products/$$row{id}/$$row{id}_fr_l.jpg\thttp://www.net-a-porter.com/images/products/$$row{id}/$$row{id}_bk_l.jpg\thttp://www.net-a-porter.com/images/products/$$row{id}/$$row{id}_cu_l.jpg\n";

}

close($OUT);

sub d2 {
    my $val = shift;
    my $n = sprintf("%.2f", $val);
    return $n;
}


