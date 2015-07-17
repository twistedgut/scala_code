#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

recent_deliveries.t - Create a purchase order and verify it appears in the recent deliveries list

=head1 DESCRIPTION

/GoodsIn/Stockin

   - Sales dropdown must have all channels listed
   - Be able to find purchase just raised

#TAGS checkruncondition jimmychoo goodsin stockin xpath http duplication whm

=head1 SEE ALSO

goods_in.t

=cut

use FindBin::libs;
use DateTime;

use Test::XTracker::RunCondition dc => 'DC1';

use Test::XTracker::Data;
use Test::XTracker::Mechanize::PurchaseOrder;
use Test::XTracker::Mechanize::GoodsIn;
use XTracker::Constants::FromDB qw(
    :channel
    :business
    :stock_order_status
    :authorisation_level
);

my $perms_operator = [{
        section     => 'Goods In',
        sub_section => 'Recent Deliveries',
        level       => $AUTHORISATION_LEVEL__OPERATOR,
    },
];

my $mech = Test::XTracker::Mechanize::GoodsIn->new;

# start testing
$mech->setup_and_login({ dept => 'Distribution Management', perms => $perms_operator});

# Create some test data
my $schema = Test::XTracker::Data->get_schema;

# Create a purchase order on each channel
my $po_mrp  = Test::XTracker::Mechanize::PurchaseOrder->create_test_data($CHANNEL__MRP_INTL);
my $po_nap  = Test::XTracker::Mechanize::PurchaseOrder->create_test_data($CHANNEL__NAP_INTL);
my $po_out  = Test::XTracker::Mechanize::PurchaseOrder->create_test_data($CHANNEL__OUTNET_INTL);
# my $po_jc   = Test::XTracker::Mechanize::PurchaseOrder->create_test_data($CHANNEL__JC_INTL);

# note "MRP PO ID [".$po_mrp->id."] NAP PO ID [".$po_nap->id."] JC PO ID [".$po_jc->id."]";

my $del_mrp     = $po_mrp->stock_orders->first->deliveries->first;
my $del_mrp_id  = $del_mrp->id;

my $del_nap     = $po_nap->stock_orders->first->deliveries->first;
my $del_nap_id  = $del_nap->id;

my $del_out     = $po_out->stock_orders->first->deliveries->first;
my $del_out_id  = $del_out->id;

# my $del_jc      = $po_jc->stock_orders->first->deliveries->first;
# my $del_jc_id   = $del_jc->id;

# note "MRP DEL ID [".$del_mrp->id."] NAP DEL ID [".$del_nap->id."] JC OUT ID [".$del_out->id."] JC DEL ID [".$del_jc->id."]";

# We need to give them a recent date so they appear in the recent deliveries list
my $dt = DateTime->now;
my $date = $dt->ymd.' '.$dt->hms;

$del_mrp->date($date);
$del_mrp->update;
$del_nap->date($date);
$del_nap->update;
$del_out->date($date);
$del_out->update;
# $del_jc->date($date);
# $del_jc->update;

my $tests = [
    {
        delivery_id     => $del_mrp_id,
        class           => 'title-MRP',
        title           => 'MRPORTER.COM',
    },
    {
        delivery_id     => $del_nap_id,
        class           => 'title-NAP',
        title           => 'NET-A-PORTER.COM',
    },
    # {
        # delivery_id     => $del_jc_id,
        # class           => 'title-JC',
        # title           => 'JimmyChoo',
    # }
];

$mech->get_ok('/GoodsIn/RecentDeliveries');

$mech->follow_link( text=>'Last' );

for my $test (@$tests) {
    my $delivery_id = $test->{delivery_id};
    note $delivery_id;
    my $channel_span = $mech->find_xpath(
        "//div[\@id='recent_deliveries']//td[. =~ '$delivery_id']/following-sibling::td[4]/span"
    )->[0];

    if ($channel_span) {
        is($mech->_strip_ws($channel_span->string_value), $test->{title}, "Recent delivery $delivery_id");
    }
    else {
        ok(0, "Cannot find channel");
    }
}

done_testing;
1;
