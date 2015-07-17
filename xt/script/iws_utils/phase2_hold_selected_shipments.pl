#!perl

=pod

Put orders on hold for phase 2 DCEA launch

=cut

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Term::ReadKey;

use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :shipment_status
    :shipment_item_status
    :order_status
);

use WWW::Mechanize;

my $mech    = WWW::Mechanize->new;

print "enter username\n";
my $username = <>;
chomp $username;
print "username is $username\n";
print "enter password\n";
ReadMode 'noecho';
my $password = <>;
ReadMode 'normal';
chomp $password;

print "enter hostname\n";
my $hostname = <>;
chomp $hostname;
my $base = 'http://'.$hostname;
print "using $base\n";
$mech->get($base.'/Login');
$mech->submit_form(
    with_fields => {
        pass     => $password,
        username => $username,
    },
);

my %orders_seen;
print "enter lines of orders to put on hold (in format: order id, shipment id)\n";

while (my $line = <>) {
    my ($order_id,$shipment_id) = ($line =~ /(\d+)\s*,\s*(\d+)/);
    next unless ($order_id && $shipment_id);
    next if ($orders_seen{$order_id});
    $orders_seen{$order_id} = 1;
    #next unless ($shipment->link_orders__shipments->first->orders->order_status_id == $ORDER_STATUS__ACCEPTED);
    warn "Putting order ".$order_id." on hold\n";
    $mech->get($base.'/CustomerCare/OrderSearch/ChangeShipmentStatus?action=Hold&order_id='.$order_id.'&shipment_id='.$shipment_id.'&reason=9&comment=DCEA+phase2+launch&norelease=1&submit=submit');
    #$mech->get($base.'/CustomerCare/OrderSearch/ChangeOrderStatus?order_id='.$order_id.'&cancel_reason_id=30&submit=submit&refund_type_id=0&send_email=no&action=Cancel');
}

