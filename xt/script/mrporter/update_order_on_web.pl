#!/opt/xt/xt-perl/bin/perl
use warnings;
use strict;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw(get_database_handle get_schema_using_dbh);
use XTracker::Comms::FCP qw( update_web_order_status);
use XTracker::Logfile qw(xt_logger);
use Getopt::Long;
use Data::Dump qw(pp);

my($channel_id,$order_number);
GetOptions(
    'channel_id=s'  => \$channel_id,
    'order_number=s'    => \$order_number,
);

die "No channel id given (--channel_id)" unless $channel_id;
die "No order number given (--order_number)" unless $order_number;

my $logger      = xt_logger('XTracker');

my $schema      = get_database_handle( { name => 'xtracker_schema', type => 'transaction' } );

my $orders      = $schema->resultset('Public::Orders');
my $channels    = $schema->resultset('Public::Channel');

my $channel     = $channels->find($channel_id); 

my $dbh_web = get_database_handle( { name => 'Web_Live_'.$channel->business->config_section, type => 'transaction' } );

foreach my $order ($orders->search({channel_id=>$channel->id,order_nr=>$order_number})->all){
    my $status = $order->shipments->first->shipment_status->status;
    print "Updating order number $order_number to status $status\n";
    update_web_order_status($dbh_web, { 'orders_id' => $order->id, 'order_status' => $status} );
    $dbh_web->commit();
}

