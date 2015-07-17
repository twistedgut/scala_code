#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;

my $dbh = read_handle();
my %season = ();

my $qry = "select * from season";

my $sth = $dbh->prepare($qry);
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ){
    $season{ $row->{id} } = $row->{season};
}

$dbh->disconnect();

open my $fh, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/am/csv/season.csv" || die "Couldn't open file: $!";

foreach my $code ( keys %season ){

    my $code        = substr $code, 0, 15; 
    my $description = substr $season{$code}, 0, 50; 
    my $lookup      = substr $season{$code}, 0, 15;
    
    $description =~ s/\r//gi;
    $description =~ s/\n//gi;
   $description =~ s/"//gi;
        $description =~ s/%//gi;
        $description =~ s/&//gi;
        $description =~ s/'//gi;
        $description =~ s/~//gi;

    print $fh "$code~$description~$lookup\r\n";
}

close $fh;
