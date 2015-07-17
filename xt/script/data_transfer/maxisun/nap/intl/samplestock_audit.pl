#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;

my $dbh = read_handle();

my $qry = "
select to_char(current_timestamp, 'DDMMYYYY') as date, p.id as product_id,
p.legacy_sku, p.style_number, s.code, pri.uk_landed_cost, sum(q.quantity) as
quantity, p.designer_id, p.season_id, sa.legacy_countryoforigin, l.location
from variant v 
left join quantity q on v.id = q.variant_id and q.channel_id = 1 and q.location_id
in (select id from location where type_id in (4,6)), 
product p 
left join legacy_designer_supplier lds on p.designer_id
= lds.designer_id
left join supplier s on lds.supplier_id = s.id, 
price_purchase pri, shipping_attribute sa, location l
where v.product_id = p.id
and p.id =
pri.product_id
and
p.id
=
sa.product_id and q.location_id = l.id
group
by
p.id,
p.legacy_sku,
p.style_number,
s.code,
pri.uk_landed_cost,
p.designer_id,
p.season_id,
sa.legacy_countryoforigin,
l.location
";

my $sth = $dbh->prepare($qry);

open my $fh, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/intl/csv/SAMPLESTOCK_AUDIT.csv" || die "Couldn't open file: $!";

$sth->execute();

print "getting sample stock\n";

print $fh "SKU,PID,Date,Style Number,Currency,Supplier Code,Cost,Location,Quantity,Designer ID,Season ID,Country of Origin\r\n";

while( my $row = $sth->fetchrow_hashref() ){

    if (!$row->{code}){
        $row->{code} = "UNKNOWN";
    }


    if ($row->{quantity} > 0) {

        $row->{style_number} =~ s/\n//;
        $row->{style_number} =~ s/\r//;

        $row->{legacy_countryoforigin} =~ s/\n//;
        $row->{legacy_countryoforigin} =~ s/\r//;

        my $cost = $row->{uk_landed_cost} * $row->{quantity};

        print $fh $row->{legacy_sku}.",";
        print $fh $row->{product_id}.",";
        print $fh $row->{date}.",";
        print $fh $row->{style_number}.",";
        print $fh "GBP,";
        print $fh $row->{code}.",";
        print $fh $cost.",";
        print $fh $row->{location}.",";
        print $fh $row->{quantity}.",";
        print $fh $row->{designer_id}.",";
        print $fh $row->{season_id}.",";
        print $fh $row->{legacy_countryoforigin};
        print $fh "\r\n";
    }
}

$dbh->disconnect();

close $fh;

