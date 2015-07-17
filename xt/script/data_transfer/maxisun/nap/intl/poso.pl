#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;

my $dbh = read_handle();

my %purchase_order = ();
my %sales_order = ();

my $po_qry = "select po.purchase_order_number, po.description, d.designer 
              from purchase_order po, designer d
              where po.designer_id = d.id
              and po.date > current_timestamp - interval '1 month'
              and po.channel_id = 1";

my $sales_qry = "select o.order_nr, c.is_customer_number 
                 from orders o, customer c
                 where o.customer_id = c.id
                 and o.date > current_timestamp - interval '1 week'
                 and o.channel_id = 1";

my $sth = $dbh->prepare($po_qry);
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ){
    $purchase_order{ $row->{purchase_order_number} } = $row->{designer};
}

my $sth1 = $dbh->prepare($sales_qry);
$sth1->execute();

while( my $row = $sth1->fetchrow_hashref() ){
    $sales_order{ $row->{order_nr} } = $row->{is_customer_number};
}

$dbh->disconnect();

open my $fh, ">", "/var/data/xt_static/utilities/data_transfer/maxisun/intl/csv/pono.csv" || die "Couldn't open file: $!";

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
