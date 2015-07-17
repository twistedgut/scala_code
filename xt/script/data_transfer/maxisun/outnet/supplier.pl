#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;
use Getopt::Long;

my $dbh     = read_handle();
my $outdir  = undef;

GetOptions(
    'outdir=s' => \$outdir,
);

die 'No output directory defined' if not defined $outdir;

open my $fh, '>', '/var/data/xt_static/data/maxisun/'.$outdir.'/suppliers.csv' || die "Couldn't open output file: $!";
print $fh "code~description~lookup\r\n";

my $qry = "SELECT SUBSTRING(code FROM 0 FOR 15) AS code, SUBSTRING(description FROM 0 FOR 50) AS description, SUBSTRING(code FROM 0 FOR 15) AS lookup FROM supplier";
my $sth = $dbh->prepare($qry);
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ){
    print $fh "$row->{code}~$row->{description}~$row->{lookup}\r\n";
}

close $fh;

$dbh->disconnect();

