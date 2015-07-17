#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;
use Getopt::Long;

my $dbh         = read_handle();
my $outdir      = undef;
my $channel_id  = undef;

GetOptions(
    'outdir=s'      => \$outdir,
    'channel_id=s'  => \$channel_id,
);

die 'No output directory defined' if not defined $outdir;
die 'No channel id defined' if not defined $channel_id;

# open output file and write header record
open my $fh, '>', '/var/data/xt_static/data/maxisun/'.$outdir.'/pono.csv' || die "Couldn't open output file: $!";
print $fh "code~description~lookup\r\n";

my %purchase_order = ();
my %sales_order = ();

my $po_qry = "select po.purchase_order_number, po.description, d.designer 
              from purchase_order po, designer d
              where po.channel_id = ? 
              and po.designer_id = d.id
              and po.date > current_timestamp - interval '1 month'";

my $sales_qry = "select o.order_nr, c.is_customer_number 
                 from orders o, customer c
                 where o.channel_id = ? 
                 and o.customer_id = c.id
                 and o.date > current_timestamp - interval '1 week'";

my $sth = $dbh->prepare($po_qry);
$sth->execute($channel_id);

while( my $row = $sth->fetchrow_hashref() ){
    $purchase_order{ $row->{purchase_order_number} } = $row->{designer};
}

my $sth1 = $dbh->prepare($sales_qry);
$sth1->execute($channel_id);

while( my $row = $sth1->fetchrow_hashref() ){
    $sales_order{ $row->{order_nr} } = $row->{is_customer_number};
}

$dbh->disconnect();


foreach my $code ( keys %purchase_order ){

    my $description = substr $purchase_order{$code}, 0, 50; 
    my $lookup      = substr $purchase_order{$code}, -15, 15;
    my $code        = substr $code, -15, 15; 

    $description =~ s/\r//;
    $description =~ s/\n//;
    $description =~ s/'//;
    $description =~ s/"//;

    $lookup =~ s/\r//;
    $lookup =~ s/\n//;
    $lookup =~ s/'//;
    $lookup =~ s/"//;
     
    print $fh "$code~$description~$lookup\r\n";
}

foreach my $code ( keys %sales_order ){

    print $fh "$code~$sales_order{$code}~$sales_order{$code}\r\n";
}

close $fh;
