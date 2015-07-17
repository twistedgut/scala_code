#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;
use Getopt::Long;

my $dbh         = read_handle();
my $outdir      = undef;

GetOptions(
    'outdir=s'      => \$outdir,
);

die 'No output directory defined' if not defined $outdir;

# open output file and write header record
open my $fh, '>', '/var/data/xt_static/data/maxisun/'.$outdir.'/desemp.csv' || die "Couldn't open output file: $!";
print $fh "code~description~lookup\r\n";

my $qry = "select id, designer from designer";
my $sth = $dbh->prepare($qry);
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ){
    print $fh $row->{id};
    print $fh "~";
    print $fh substr $row->{designer}, 0, 50;
    print $fh "~";
    print $fh substr $row->{designer}, 0, 15;
    print $fh "\r\n";
}

$dbh->disconnect();

close $fh;
