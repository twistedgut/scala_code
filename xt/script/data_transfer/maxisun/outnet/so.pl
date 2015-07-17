#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;
use XTracker::Database::Order qw( get_order_total_charge );
use Getopt::Long;
use DateTime;
use XTracker::Constants::FromDB qw( :shipment_item_status );

my $dbh         = read_handle();
my $outdir      = undef;
my $channel_id  = undef;
my $dt          = DateTime->now(time_zone => "local");
my %data        = ();

my $to          = $dt->date;
my $from        = $dt->subtract( days => 1 )->date;

GetOptions(
    'outdir=s'      => \$outdir,
    'channel_id=s'  => \$channel_id,
);

die 'No output directory defined' if not defined $outdir;
die 'No channel id defined' if not defined $channel_id;


# open output file and write header record
open my $fh, '>', '/var/data/xt_static/data/maxisun/'.$outdir.'/so.csv' || die "Couldn't open output file: $!";
print $fh "type~date~empty1~airway_bill~currency~value~empty2~empty3~empty4~empty5~empty6~empty7~empty8~empty9~order_number~empty10~empty11~code\r\n";

# get data for output file
my $qry = "select o.order_nr, o.id, to_char(sisl.date, 'DDMMYYYY') as date, o.store_credit, o.gift_credit, cp.psp_ref as transaction_ref, c.currency
            from orders o left join orders.payment cp on o.id = cp.orders_id, currency c, link_orders__shipment los, shipment s, shipment_item si, shipment_item_status_log sisl
            where o.id = los.orders_id
            and los.shipment_id = s.id
            and s.shipment_class_id = 1
            and s.id = si.shipment_id
            and si.id = sisl.shipment_item_id
            and sisl.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED
            and sisl.date between ? and ?
            and o.currency_id = c.id
            and o.channel_id = ?";

my $sth = $dbh->prepare($qry);
$sth->execute($from, $to, $channel_id);

while( my $row = $sth->fetchrow_hashref() ){

    if (!$data{ $row->{id} }){

        $data{$row->{id}} = 1;

        if (!$row->{transaction_ref}){ 
            $row->{transaction_ref} = $row->{order_nr}; 
        }

        my $total_charge = get_order_total_charge($dbh, $row->{id});

        if ($row->{store_credit} < 0){
            print $fh "CUSTNO~$row->{date}~~$row->{transaction_ref}~$row->{currency}~".( $row->{store_credit} * -1 )."~~~~~~~~~$row->{order_nr}~~~2\r\n";
        }

        if ($row->{gift_credit} < 0){
            print $fh "GCERT~$row->{date}~~$row->{transaction_ref}~$row->{currency}~".( $row->{gift_credit} * -1 )."~~~~~~~~~$row->{order_nr}~~~3\r\n";
        }
        
        if ( $total_charge > 0.01 ){
            print $fh "CUSTNO~$row->{date}~~$row->{transaction_ref}~$row->{currency}~$total_charge~~~~~~~~~$row->{order_nr}~~~1\r\n";
        }

    }
}

close $fh;


$dbh->disconnect();
