#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;
use Getopt::Long;

my $dbh         = read_handle();
my $outdir      = undef;
my %sku         = ();

GetOptions(
    'outdir=s'      => \$outdir,
);

die 'No output directory defined' if not defined $outdir;

# open output file and write header record
open my $fh, '>', '/var/data/xt_static/data/maxisun/'.$outdir.'/sku.csv' || die "Couldn't open output file: $!";
print $fh 'code~description~lookup';

my $qry = "
select p.legacy_sku, pa.description from product p, product_attribute pa where p.id in 
(select product_id from stock_order
where purchase_order_id in (select id from purchase_order where date >
current_timestamp - interval '1 month')) 
and p.id = pa.product_id
";

my $sth = $dbh->prepare($qry);
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ){
    $sku{ $row->{legacy_sku} } = $row->{description};
} 

$dbh->disconnect();


foreach my $code ( keys %sku ){

    my $code        = substr $code, 0, 15; 
    my $description = substr $sku{$code}, 0, 50; 
    my $lookup      = substr "none-none", 0, 11;
    $description =~ s/\r//g;
    $description =~ s/\n//g;
    $description =~ s/"//gi;
    $description =~ s/!//gi;
    $description =~ s/%//gi;
    $description =~ s/&//gi;
    $description =~ s/'//gi;
    $description =~ s/~//gi;
    $description =~ s/,//gi;

    print $fh "$code~$description~$lookup\r\n";
}

close $fh;
