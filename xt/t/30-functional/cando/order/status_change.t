#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Mechanize;

my $mech = Test::XTracker::Mechanize->new;
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::CustomerCare',
    ],
    mech => $mech,
);

# Grab a product for this channel
my (undef, $products) = Test::XTracker::Data->grab_products({
    how_many            => 1,
    channel             => Test::XTracker::Data->channel_for_nap,
});

my $xml_parser = Test::XTracker::Data::Order::Parser::PublicWebsiteXML->new();
my ($order_obj) = $xml_parser->create_and_parse_order({
                        items => [{sku => $products->[0]->{variant}->sku}],
                  });
my $order = $order_obj->digest();

note( $order->order_nr . ' [' . $order->id . ']');

# Ensure order is on credit hold
ok($order->is_on_credit_hold, 'Order is on credit hold');

# Credentials
$framework->login_with_roles( {
    paths => [ qw(
        /Finance/Order/Accept
        /Finance/Order/CreditHold
    ) ],
    main_nav => [
        'Customer Care/Customer Search',
    ],
} );

# Accept order
ok($order->is_on_credit_hold, 'Order is on credit hold');
$framework->flow_mech__customercare__orderview($order->id);
$framework->flow_mech__customercare__accept_order;

# Ensure order and shipments are accepted
$order->discard_changes;
ok($order->is_accepted, 'Order is accepted');

my $shipments = $order->shipments;
while (my $shipment = $shipments->next){
    ok($shipment->is_processing, 'Shipment is processing');
}

# Put order on credit hold
$framework->flow_mech__customercare__put_on_credit_hold;

# Ensure order and shipments are on credit/finance hold
$order->discard_changes;
ok($order->is_on_credit_hold, 'Order is on credit hold');

$shipments->reset;
while (my $shipment = $shipments->next){
    ok($shipment->is_on_finance_hold, 'Shipment is on finance hold');
}

done_testing;
