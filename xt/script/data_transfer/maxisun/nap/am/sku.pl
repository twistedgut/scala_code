#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;

my $dbh = read_handle();
my %sku = ();

my $qry = "select p.legacy_sku, pa.description from product p, product_attribute pa where p.season_id > 34 and p.id = pa.product_id";

my $sth = $dbh->prepare($qry);
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ){
    $sku{ $row->{legacy_sku} } = $row->{description};
} 

$dbh->disconnect();

open my $fh, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/am/csv/sku.csv" || die "Couldn't open file: $!";

foreach my $code ( keys %sku ){

    my $code        = substr $code, 0, 15; 
    my $description = substr $sku{$code}, 0, 50; 
    my $lookup      = substr "none-none", 0, 11;
    $description =~ s/\r//gi;
    $description =~ s/\n//gi;
    $description =~ s/"//gi;
    $description =~ s/%//gi;
    $description =~ s/&//gi;
    $description =~ s/!//gi;
    $description =~ s/'//gi;
    $description =~ s/~//gi;
    $description =~ s/,//gi;

    print $fh "$code~$description~$lookup\r\n";
}

close $fh;
