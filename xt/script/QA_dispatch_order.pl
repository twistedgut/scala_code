#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;

=head1 NAME

QA_dispatch_order.pl

=head1 SETUP

To set this script up for QA to run it, please ensure that the following is in
the C<.bash_profile> for the user QA are using - which is currently napuser:

 export NO_XT_LOGGER=1
 cat <<EOF
 |                                                                      |
 | Script to Dispatch an order:                                         |
 |     /opt/xt/deploy/xtracker/script/QA_dispatch_order.pl <order_nr>   |
 |                                                                      |
 +----------------------------------------------------------------------+
 EOF

(Remove the leading spaces if any.)

=cut

my ($USERNAME, $PASSWORD, $HOSTNAME);

BEGIN {
  use Sys::Hostname;
  # Only edit the next 3 lines
  $USERNAME = 'it.god';
  $PASSWORD = 'it.god';
  ($HOSTNAME = hostname) =~ s/\..*$//;

  # Dont edit anything below here!
  #
}

BEGIN {
  my %known_am_hosts = (
    'vaderv02',
    'kingpinv10'
  );

  if (exists $known_am_hosts{$HOSTNAME}) {
    $ENV{XT_CONFIG_LOCAL_SUFFIX} = 'test_am';
  }

}


use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use lib "$Bin/../t/lib";
use FindBin::libs qw( base=lib_dynamic );
use utf8;

use Test::More;
use Test::XTracker::Data;
use Test::XTracker::Mechanize;


# Now fix up the Database_xtracker_local section to talk to the DB on the host
local $XTracker::Config::Local::config{Database_xtracker}{db_host} = $HOSTNAME;


my $order_nr =  shift or usage();


setup_user_perms();

my $mech = Test::XTracker::Mechanize->new(base => "http://localhost/");
$mech->login_ok($USERNAME, $PASSWORD);

$mech->order_nr($order_nr);

my ($ship_nr, $status, $category) = gather_order_info();
diag "Shipment Nr: $ship_nr" if $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE};

# The order status might be Credit Hold. Check and fix if needed
if ($status eq "Credit Hold") {
  Test::XTracker::Data->set_department($USERNAME, 'Finance');
  $mech->reload;
  $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
  ($ship_nr, $status, $category) = gather_order_info();
}
is($status, $mech->get_table_value('Order Status:'), "Order is accepted");



#$mech->test_select_order($category,$ship_nr, 'NET-A-PORTER.COM');
$mech->test_direct_select_shipment($ship_nr);


my $skus = $mech->get_order_skus();
# Get the location from the picking list
$skus = $mech->get_info_from_picklist($skus);

$mech->test_pick_shipment($ship_nr, $skus)
     ->test_pack_shipment($ship_nr, $skus)
     ->test_assign_airway_bill($ship_nr)
     ->test_dispatch($ship_nr)
     ;

done_testing;






sub setup_user_perms {
  Test::XTracker::Data->set_department($USERNAME, 'Distribution');
  Test::XTracker::Data->grant_permissions($USERNAME, 'Customer Care', 'Order Search', 2);
  # Perms needed for the order process
  for (qw/Airwaybill Dispatch Packing Picking Selection/ ) {
    Test::XTracker::Data->grant_permissions($USERNAME, 'Fulfilment', $_, 2);
  }
}



# First time check that we can get the order via search
# Other times go straight to that url
sub gather_order_info {
  my ($order_nr) = @_;

  $mech->get_ok($mech->order_view_url);

  # On the order view page we need to find the shipment ID

  my $ship_nr = $mech->get_table_value('Shipment Number:');

  my $status = $mech->get_table_value('Order Status:');


  my $category = $mech->get_table_value('Customer Category:');
  return ($ship_nr, $status, $category);
}

sub usage {
  print STDERR "Usage: $0 order_nr\n";
  exit 1;
}

