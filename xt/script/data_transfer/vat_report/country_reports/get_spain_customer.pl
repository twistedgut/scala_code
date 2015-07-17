#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib";
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Database;

# get list of invoices
my $dbh = read_handle();

my $qry = "
select is_customer_number, first_name, last_name, email, telephone_1 from customer where id in (select customer_id from orders where id in (select orders_id from link_orders__shipment where shipment_id in (select id from shipment where shipment_address_id in (select id from order_address where country = 'Spain'))))
";
my $sth = $dbh->prepare($qry);
$sth->execute();

open (my $OUT,'>','/opt/xt/deploy/xtracker/script/data_transfer/vat_report/output/spanish_customers.csv') || warn "Cannot open site input file: $!";

while(my $row = $sth->fetchrow_arrayref){

    print $OUT $row->[0].",".$row->[1].",".$row->[2].",".$row->[3].",".$row->[4]."\r\n";

}

close($OUT);
