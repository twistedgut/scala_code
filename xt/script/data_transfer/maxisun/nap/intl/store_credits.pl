#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;

my $dbh = read_handle();

open (my $OUT,">","/var/data/xt_static/utilities/data_transfer/maxisun/intl/csv/store_credits.csv") || warn "Cannot open site input file: $!";

my $qry = "
select c.first_name, c.last_name, c.is_customer_number, c.email, cc.credit, cur.currency, to_char(max(ccl.date), 'DD-MM-YYYY')
        from customer c, customer_credit cc left join customer_credit_log ccl on cc.customer_id = ccl.customer_id, currency cur
        where c.id = cc.customer_id
    and cc.currency_id = cur.id
    and cc.credit > 0
    and cc.channel_id = 1
    group by c.first_name, c.last_name, c.is_customer_number, c.email, cc.credit, cur.currency
";

my $sth = $dbh->prepare($qry);

$sth->execute();

while(my $row = $sth->fetchrow_arrayref){
        print $OUT "".$row->[0]." ".$row->[1].",".$row->[2].",".$row->[3].",".$row->[4].",".$row->[5].",".$row->[6]."\n";
}

close($OUT);
