#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;

my $dbh = read_handle();
my %supplier = ();

my $qry = "select * from supplier";

my $sth = $dbh->prepare($qry);
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ){
    $supplier{ $row->{code} } = $row->{description};
}

$dbh->disconnect();

open my $fh, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/intl/csv/suppliers.csv" || die "Couldn't open file: $!";

foreach my $code ( keys %supplier ){

    my $code        = substr $code, 0, 15; 
    my $description = substr $supplier{$code}, 0, 50; 
    my $lookup      = substr $supplier{$code}, 0, 15;
$description =~ s/\r//;
    $description =~ s/\n//;
    print $fh "$code~$description~$lookup\r\n";
}

close $fh;
