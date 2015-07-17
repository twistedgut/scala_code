#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::MessageQueue;
use Test::XTracker::Mechanize;
use Test::XTracker::Artifacts::RAVNI;
use XTracker::Constants::FromDB qw(
    :storage_type
);

use Test::XTracker::Data::Order::Parser::PublicWebsiteXML;

use Test::XTracker::RunCondition
    export => ['$distribution_centre','$prl_rollout_phase'];

use XTracker::Constants::FromDB     qw( :business );

my $schema = Test::XTracker::Data->get_schema;

my $amq = Test::XTracker::MessageQueue->new;

my (undef,$pids) = Test::XTracker::Data->grab_products({
    how_many => 1,
    channel => 'nap',
    how_many_variants => 2,
    ensure_stock_all_variants => 1,
    storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
});

my $PID = $pids->[0]{pid};
my $SIZE = $pids->[0]{size_id};
my $old_sku = $pids->[0]{'sku'};


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

my $prl_msgs = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

Test::XTracker::Data::Order->allocate_order($order->discard_changes);

my $allocation_id = check_allocation_messages($old_sku);

my $mech = Test::XTracker::Mechanize->new;
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::PRL',
    ],
    mech => $mech,
);

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

my ($ship_nr, $status, $category) = gather_order_info();
note "Shipment Nr: $ship_nr" if $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE};

# The order status might be Credit Hold. Check and fix if needed
if ($status eq "Credit Hold") {
  Test::XTracker::Data->set_department('it.god', 'Finance');
  $mech->reload;
  $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
  ($ship_nr, $status, $category) = gather_order_info();
}
is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

if ($prl_rollout_phase) {
    Test::XTracker::Data::Order->select_order($order);
    $framework->flow_msg__prl__send_pick_for_allocation($allocation_id);
} else {
    $mech->test_select_order($category,$ship_nr); # TODO DCA-2261: do we still need this for non-prl?
}

check_pick_message($allocation_id);

Test::XTracker::Data->set_department('it.god', 'Customer Care Manager');

my $queue = $mech->nap_order_update_queue_name();

$amq->clear_destination($queue);

# Change the size, and confirm we actually have done...
$mech->test_size_change_order($order);
$order->discard_changes();

# Find the new shipment item...
my $new_sku = $order->shipments->first
    ->shipment_items->search({
        variant_id => { '!=' => $pids->[0]{'variant_id'}}}
    )->first->variant->sku;

my ($before_product, $before_size) = split(/-/, $old_sku);
my ($after_product, $after_size)   = split(/-/, $new_sku);

is( $before_product, $after_product, "Product matches after size change" );
isnt( $before_size, $after_size, "Size is different after size change" );

check_allocation_messages($new_sku, $allocation_id);

$new_sku = $order->shipments->first
    ->shipment_items->first->variant->sku;

$amq->assert_messages( {
    destination => $queue,
    assert_header => superhashof({
        type => 'OrderMessage',
    }),
    assert_body => superhashof({
        '@type' => 'order',
        orderNumber => $order->order_nr,
    }),
}, 'update message sent');

done_testing;


sub check_allocation_messages {
    my $sku = shift;
    return unless $prl_rollout_phase;

    my @msgs = $prl_msgs->new_files();
    is( (scalar @msgs), 1, "Found a PRL message" );

    my $msg = $msgs[0];
    is( $msg->payload_parsed->{'@type'}, 'allocate', "Message is 'allocate'");

    # If it's already set, check the newest message matches it
    if ( $allocation_id ) {
        isnt( $msg->payload_parsed->{'allocation_id'}, $allocation_id,
            "Allocation ID not reused because pick has been sent" );
    # If it's not set, set it from this message
    } else {
        $allocation_id = $msg->payload_parsed->{'allocation_id'};
        note "Allocation ID set to $allocation_id";
    }

    # Check we just have one set of item details
    my @item_details = @{ $msg->payload_parsed->{'item_details'} };
    is( (scalar @item_details), 1, "One item only in allocation message" );

    # Check the SKU and quantity match expectations
    is( $item_details[0]->{'sku'}, $sku, "SKU as expected" );
    is( $item_details[0]->{'quantity'}, 1, "Quantity as expected" );

    return $allocation_id;
}


sub check_pick_message {
    my $allocation_id = shift;
    return unless $prl_rollout_phase;

    my @msgs = $prl_msgs->new_files();
    is( (scalar @msgs), 1, "Found a PRL message" );

    my $msg = $msgs[0];
    is( $msg->payload_parsed->{'@type'}, 'pick', "Message is 'pick'");

    is( $msg->payload_parsed->{'allocation_id'}, $allocation_id,
            "Allocation ID is correct" );
}



# First time check that we can get the order via search
# Other times go straight to that url
sub gather_order_info {

  $mech->get_ok($mech->order_view_url);

  # On the order view page we need to find the shipment ID

  my $ship_nr = $mech->get_table_value('Shipment Number:');

  my $status = $mech->get_table_value('Order Status:');


  my $category = $mech->get_table_value('Customer Category:');

  return ($ship_nr, $status, $category);
}
