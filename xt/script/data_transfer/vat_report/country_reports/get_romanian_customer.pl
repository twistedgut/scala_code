#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib";
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Database;

# get list of invoices
my $dbh = read_handle();

my $qry = "
select is_customer_number, first_name, last_name from customer where id in (select customer_id from orders where invoice_address_id in (select id from order_address where country = 'Romania'))
";
my $sth = $dbh->prepare($qry);
$sth->execute();

open (my $OUT,'>','/opt/xt/deploy/xtracker/script/data_transfer/vat_report/output/romanian_customers.csv') || warn "Cannot open site input file: $!";

while(my $row = $sth->fetchrow_arrayref){
    print $OUT $row->[0].",".$row->[1].",".$row->[2]."\r\n";
}

close($OUT);
