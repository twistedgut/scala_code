#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;

my $dbh = read_handle();

open (my $OUT,">","/var/data/xt_static/utilities/data_transfer/maxisun/intl/csv/gift_credits.csv") || warn "Cannot open site input file: $!";

my $qry = "
select g.first_name, g.last_name, g.customer_number, g.email, g.value, cur.currency
        from gift_credit g, currency cur
        where g.activated = false
    and g.currency_id = cur.id
";

my $sth = $dbh->prepare($qry);

$sth->execute();

while(my $row = $sth->fetchrow_arrayref){
        print $OUT "".$row->[0]." ".$row->[1].",".$row->[2].",".$row->[3].",".$row->[4].",".$row->[5]."\n";
}

close($OUT);
