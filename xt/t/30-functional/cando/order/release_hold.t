#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::Data;
use Test::XTracker::Mechanize::PurchaseOrder;
use Test::XTracker::Mechanize::GoodsIn;
use XTracker::Constants::FromDB qw(
    :business
    :stock_order_status
    :authorisation_level
);

# /GoodsIn/Stockin
#   - sales dropdown has all channels listed
#   - be able to find PO just raised
#
#
my $perms_operator = [{
        section     => 'Goods In',
        sub_section => 'Delivery Hold',
        level       => $AUTHORISATION_LEVEL__OPERATOR,
    },
];
my $perms_manager = [{
        section     => 'Goods In',
        sub_section => 'Delivery Hold',
        level       => $AUTHORISATION_LEVEL__MANAGER,
    },
];

my $mech = Test::XTracker::Mechanize::GoodsIn->new;

# start testing
$mech->setup_and_login({ dept => 'Distribution Management', perms => $perms_operator});

# Create some test data
my $schema = Test::XTracker::Data->get_schema;

# Create a purchase order on the MR.PORTER channel
my $po      = Test::XTracker::Mechanize::PurchaseOrder->create_test_data;
my $po_id   = $po->id;
note "Purchase Order id [$po_id]\n";

my $delivery = $po->stock_orders->first->deliveries->first;
note "delivery id is [".$delivery->id."]";
# Change the delivery to 'on hold'
$delivery->hold;

$mech->test_release_hold($po, $AUTHORISATION_LEVEL__OPERATOR);

$mech->setup_and_login({ dept => 'Distribution Management', perms => $perms_manager});

$mech->test_release_hold($po, $AUTHORISATION_LEVEL__MANAGER);

done_testing;
1;
