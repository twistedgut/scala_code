#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib";
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Database;

# get list of invoices
my $dbh = read_handle();

my $qry = "
select p.id, c.classification, pt.product_type
from product p, classification c, product_type pt, variant v
where p.id = v.product_id
and v.id in (select variant_id from shipment_item where shipment_id in (select id from shipment where date > current_timestamp - interval '40 days' ))
and p.classification_id = c.id
and p.product_type_id = pt.id
";
my $sth = $dbh->prepare($qry);
$sth->execute();

open (my $OUT,'>','/opt/xt/deploy/xtracker/script/data_transfer/vat_report/output/Spain_product_list.csv') || warn "Cannot open site input file: $!";

while(my $row = $sth->fetchrow_arrayref){

    print $OUT $row->[0].",".$row->[1].",".$row->[2]."\r\n";

}

close($OUT);
