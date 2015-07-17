#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::MessageQueue;
use Test::XTracker::Mechanize;
use Test::XTracker::Artifacts::RAVNI;

use Test::XTracker::Data::Order::Parser::PublicWebsiteXML;
use XTracker::Constants::FromDB     qw( :business );

use Test::XTracker::RunCondition export => ['$distribution_centre', '$prl_rollout_phase'];

my $schema = Test::XTracker::Data->get_schema;

my $amq = Test::XTracker::MessageQueue->new;

# delete all existing xml files in case of previously crashed test:
Test::XTracker::Data::Order->purge_order_directories;

my (undef,$pids) = Test::XTracker::Data->grab_products({
    how_many => 1,
    channel => 'nap',
});

my $PID = $pids->[0]{pid};
my $SIZE = $pids->[0]{size_id};

my $xml_parser = Test::XTracker::Data::Order::Parser::PublicWebsiteXML->new();
my $channel    = $schema->resultset('Public::Business')->find($BUSINESS__NAP)->channels->first;

my ($order_obj) = $xml_parser->create_and_parse_order({
    customer => {
        id => Test::XTracker::Data->create_dbic_customer({
            channel_id => $channel->id
        })->id,
    },
    order => {
        channel_prefix => $channel->business->config_section,
        items => [
            {
                sku         => $pids->[0]{sku},
                ol_id       => 1,
                description => 'big pants',
                unit_price  => 10,
                tax         => 10,
                duty        => 10,
            }
        ],
    }
});

my $order = $order_obj->digest();
my $order_nr = $order_obj->order_number;

Test::XTracker::Data->ensure_stock($PID, $SIZE);

my $shipment = $order->shipments->first;
Test::XTracker::Data::Order->allocate_order($order);

my $framework = Test::XT::Flow->new_with_traits();
my $mech = $framework->mech;

my $queue = $mech->nap_order_update_queue_name();
$amq->clear_destination($queue);

$framework->login_with_roles( {
    paths => [
        '/Finance/Order/Accept',
    ],
    main_nav => [
        'Customer Care/Order Search',
        'Fulfilment/Airwaybill',
        'Fulfilment/Dispatch',
        'Fulfilment/Packing',
        'Fulfilment/Picking',
        'Fulfilment/Selection',
    ],
    setup_fallback_perms => 1,
} );

$mech->order_nr($order_nr);

my ($ship_nr, $status, $category) = gather_order_info($mech);
note "Shipment Nr: $ship_nr" if $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE};

# The order status might be Credit Hold. Check and fix if needed
if ($status eq "Credit Hold") {
  Test::XTracker::Data->set_department('it.god', 'Finance');
  $mech->reload;
  $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
  ($ship_nr, $status, $category) = gather_order_info($mech);
}
is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

# $mech->test_select_order($category,$ship_nr); # TODO DCA-2261: do we still need this for non-prl?
Test::XTracker::Data::Order->select_order($order->discard_changes);

my $skus = $mech->get_order_skus();
# Get the location from the picking list

# Setup the message monitor
my $prl_msgs = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
# Cancel the order
$mech->test_cancel_order();

$amq->assert_messages( {
    destination => $queue,
    assert_header => superhashof({
        type => 'OrderMessage',
    }),
    assert_body => superhashof({
        '@type' => 'order',
        orderNumber => $order->order_nr,
    }),
}, 'Order message sent');

# clear out any Order XML files
Test::XTracker::Data::Order->purge_order_directories();

done_testing;



sub check_allocation_messages {
    my $prl_msgs = shift;
    return unless $prl_rollout_phase;

    my @msgs = $prl_msgs->new_files();
    is( (scalar @msgs), 1, "Found a PRL message" )
      || return;

    my $msg = $msgs[0];
    is( $msg->payload_parsed->{'@type'}, 'allocate', "Message is 'allocate'")
      || return;

    # Check we just have one set of item details
    my @item_details = @{ $msg->payload_parsed->{'item_details'} };
    is_deeply(\@item_details, [], "Allocation cancels all items");
}


# First time check that we can get the order via search
# Other times go straight to that url
sub gather_order_info {
  my $mech = shift;
  $mech->get_ok($mech->order_view_url);

  # On the order view page we need to find the shipment ID

  my $ship_nr = $mech->get_table_value('Shipment Number:');

  my $status = $mech->get_table_value('Order Status:');


  my $category = $mech->get_table_value('Customer Category:');

  return ($ship_nr, $status, $category);
}

