#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;

my $dbh = read_handle();

my %sku = ();

my $qry = "select v.legacy_sku from variant v";

my $sth = $dbh->prepare($qry);
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ){
    $sku{ $row->{legacy_sku} } = 1;
} 

$dbh->disconnect();

open my $fh, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/intl/csv/allsku.csv" || die "Couldn't open file: $!";

foreach my $sku ( keys %sku ){

    print $fh "$sku\r\n";
}

close $fh;
