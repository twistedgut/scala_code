#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;

my $dbh = read_handle();

my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst)=localtime(time);
$month++;
$year = $year+1900;

my $start = ((localtime(time-86400))[5] + 1900)."-".((localtime(time-86400))[4] + 1)."-".((localtime(time-86400))[3]);
my $end = $year."-".$month."-".$day;

my $start = '2008-07-06';
my $end = '2008-07-19';

my $qry = "
select c.is_customer_number, to_char(ccl.date, 'DDMMYYYY') as date, ccl.change, cur.currency, ccl.action 
from customer c, customer_credit cc, customer_credit_log ccl, currency cur 
where c.id = ccl.customer_id 
and ccl.date between ? and ?
and ccl.action not like 'Order - %' and ccl.action not like 'Refund - %' 
and c.id = cc.customer_id 
and cc.currency_id = cur.id
";

my $sth = $dbh->prepare($qry);

open my $fh, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/intl/csv/store_credit_adjustment.csv" || die "Couldn't open file: $!";

$sth->execute($start, $end);

while ( my $row = $sth->fetchrow_hashref() ) {

    print $fh $row->{is_customer_number}."~";
    print $fh $row->{date}."~";
    print $fh $row->{change}."~";
    print $fh $row->{currency}."~";
    print $fh $row->{action}."\r\n";
}

$dbh->disconnect();

close $fh;

