#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;
use XTracker::Database::Order qw( get_order_total_charge );
use XTracker::Constants::FromDB qw( :shipment_item_status );

my $dbh = read_handle();

my %orders   = ();

my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst)=localtime(time); $month++; $year = $year+1900;

my $start = ((localtime(time-86400))[5] + 1900)."-".((localtime(time-86400))[4] + 1)."-".((localtime(time-86400))[3]);
my $end = $year."-".$month."-".$day;


my $qry = "
select o.order_nr, o.id, to_char(sisl.date, 'DDMMYYYY') as date, o.store_credit, o.gift_credit, cp.psp_ref as
transaction_ref, c.currency
    from orders o left join orders.payment cp on o.id = cp.orders_id, currency c, link_orders__shipment los, shipment s, shipment_item si, shipment_item_status_log sisl
        where o.id = los.orders_id
        and los.shipment_id = s.id
        and s.shipment_class_id = 1
        and s.id = si.shipment_id
        and si.id = sisl.shipment_item_id
        and sisl.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED
        and sisl.date between ? and ?
        and o.currency_id = c.id
        and o.channel_id = 1
";

my $sth = $dbh->prepare($qry);

$sth->execute($start, $end);

open my $fh, ">","/var/data/xt_static/utilities/data_transfer/maxisun/intl/csv/so.csv" || die "Couldn't open file: $!";

while( my $row = $sth->fetchrow_hashref() ){

if (!$orders{$row->{id}}){

    $orders{$row->{id}} = 1;

    if (!$row->{transaction_ref}){ $row->{transaction_ref} = $row->{order_nr}; }

    my $total_charge = get_order_total_charge($dbh, $row->{id});

    if ($row->{store_credit} < 0) {
        print $fh "CUSTNO~";
        print $fh "$row->{date}~";
        print $fh "~";
        print $fh "$row->{transaction_ref}~";
        print $fh "$row->{currency}~";
        print $fh "".( $row->{store_credit} * -1 )."~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "$row->{order_nr}~";
        print $fh "~";
        print $fh "~";
        print $fh "2";
        print $fh "\r\n";
    }

    if ($row->{gift_credit} < 0) {
        print $fh "GCERT~";
        print $fh "$row->{date}~";
        print $fh "~";
        print $fh "$row->{transaction_ref}~";
        print $fh "$row->{currency}~";
        print $fh "".($row->{gift_credit} * -1 )."~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "$row->{order_nr}~";
        print $fh "~";
        print $fh "~";
        print $fh "3";
        print $fh "\r\n";
    }

    print $total_charge."\n";


    ### CARD PAYMENTS
    if ( $total_charge > 0.01 ) {
        print $fh "CUSTNO~";
        print $fh "$row->{date}~";
        print $fh "~";
        print $fh "$row->{transaction_ref}~";
        print $fh "$row->{currency}~";
        print $fh "$total_charge~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "~";
        print $fh "$row->{order_nr}~";
        print $fh "~";
        print $fh "~";
        print $fh "1";
        print $fh "\r\n";
    }

  }
}
close $fh;


$dbh->disconnect();



