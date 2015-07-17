#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::MessageQueue;
use Test::XTracker::Mechanize;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::RunCondition export => ['$distribution_centre', '$prl_rollout_phase'];

use Test::XTracker::Data::Order::Parser::PublicWebsiteXML;
use XTracker::Constants::FromDB     qw( :business :storage_type );


my $mech = Test::XTracker::Mechanize->new;
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::PRL',
    ],
    mech => $mech,
);

my $schema = $mech->schema;
my $amq = Test::XTracker::MessageQueue->new;
my $prl_msgs = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

# delete all existing xml files in case of previously crashed test:
Test::XTracker::Data::Order->purge_order_directories;

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

# Get two products of the same storage type so that they'll be in the same
# allocation, if we're working with PRLs
my (undef,$pids) = Test::XTracker::Data->grab_products({
    how_many => 2,
    channel => 'nap',
    storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
});

my $PID = $pids->[0]{pid};
my $SIZE = $pids->[0]{size_id};

my $xml_parser = Test::XTracker::Data::Order::Parser::PublicWebsiteXML->new();
my $channel    = $schema->resultset('Public::Business')->find($BUSINESS__NAP)->channels->first;

if ($prl_rollout_phase) {
    # We've added tests in here for the messages that should be sent
    # to PRLs, and these are different depending on whether we have
    # selected the shipment before we cancel the item.
    test_cancellation({'do_selection' => 0});
}

# Test this whatever PRL phase we're in.
test_cancellation({'do_selection' => 1});

# clear our order files
Test::XTracker::Data::Order->purge_order_directories();

done_testing;

sub test_cancellation {
    my ($args) = @_;

    Test::XTracker::Data::Order->purge_order_directories;

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
                },
                {
                    sku         => $pids->[1]{sku},
                    ol_id       => 2,
                    description => 'big pants',
                    unit_price  => 10,
                    tax         => 10,
                    duty        => 10,
                }
            ],
        }
    });

    my $order = $order_obj->digest();
    my $order_nr = $order->order_nr;

    Test::XTracker::Data::Order->allocate_order($order->discard_changes);

    my $allocation_id = check_allocate_message([ $pids->[0]{'sku'}, $pids->[1]{'sku'}]);

    $mech->order_nr($order_nr);

    my ($ship_nr, $status, $category) = gather_order_info();
    note "Shipment Nr: $ship_nr" if $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE};

    my $shipment = $schema->resultset('Public::Shipment')->find($ship_nr);
    my $shipment_item_to_cancel = $shipment->items_by_sku($pids->[0]{'sku'})->first;

    # The order status might be Credit Hold. Check and fix if needed
    if ($status eq "Credit Hold") {
      Test::XTracker::Data->set_department('it.god', 'Finance');
      $mech->reload;
      $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
      ($ship_nr, $status, $category) = gather_order_info();
    }
    is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

    if ($args->{do_selection}) {
        if ($prl_rollout_phase) {
            Test::XTracker::Data::Order->select_order($order);
            $framework->flow_msg__prl__send_pick_for_allocation($allocation_id);
        } else {
            $mech->test_select_order($category,$ship_nr); # TODO DCA-2261: do we still need this for non-prl?
        }
    }

    Test::XTracker::Data->set_department('it.god', 'Customer Care Manager');

    my $queue = $mech->nap_order_update_queue_name();
    $amq->clear_destination($queue);

    # In the PRL, if we've started selection (i.e. our allocation item is now
    # in 'picking'), we can't cancel directly - we have to pass through 'cancel
    # pending'
    my $expect_cancel_pending = $prl_rollout_phase && $args->{do_selection};
    $mech->test_cancel_order_item(
        $order, $expect_cancel_pending, $shipment_item_to_cancel->id
    );

    if ($args->{do_selection}) {
        # If we've already selected the shipment, there should've been a pick
        # message and we should NOT have sent a new allocate message.
        check_pick_message($allocation_id);
    } else {
        # But if we didn't select it, we should've sent a new allocate message
        # containing only the un-cancelled sku.
        check_allocate_message([ $pids->[1]{'sku'} ], $allocation_id);
    }

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
}

sub check_allocate_message {
    my ($skus, $allocation_id) = shift;
    return unless $prl_rollout_phase;

    my @msgs = $prl_msgs->new_files();
    is( (scalar @msgs), 1, "Found a PRL message" );

    use Data::Dumper;
    foreach my $msg (@msgs) {
        note Dumper($msg->payload_parsed);
    }
    my $msg = $msgs[0];
    is( $msg->payload_parsed->{'@type'}, 'allocate', "Message is 'allocate'");

    # If it's already set, check the newest message matches it
    if ( $allocation_id ) {
        is( $msg->payload_parsed->{'allocation_id'}, $allocation_id,
            "Allocation ID reused" );
    # If it's not set, set it from this message
    } else {
        $allocation_id = $msg->payload_parsed->{'allocation_id'};
        note "Allocation ID set to $allocation_id";
    }

    # Check we just have one set of item details
    my @item_details = @{ $msg->payload_parsed->{'item_details'} };
    is( (scalar @item_details), (scalar @$skus),
        "Correct number of SKUs in allocation message" );

    my @skus_found = map { $_->{'sku'} } @item_details;

    # Check the SKU and quantity match expectations
    is_deeply( \@skus_found, $skus, "SKUs as expected" );

    return $allocation_id;
}

sub check_pick_message {
    my ($allocation_id) = shift;
    return unless $prl_rollout_phase;

    my @msgs = $prl_msgs->new_files();
    is( (scalar @msgs), 1, "Found a PRL message" );

    my $msg = $msgs[0];
    is( $msg->payload_parsed->{'@type'}, 'pick', "Message is 'pick'");

    is( $msg->payload_parsed->{'allocation_id'}, $allocation_id,
        "Correct allocation ID used" );
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


sub ensure_stock {
  my ($pid, $size) = @_;

  # This could do with being smarter. For now just set the stock to 'lots'
  Test::XTracker::Data->set_product_stock({
    product_id => $pid,
    size_id => $size,
    quantity => 100
  });
}
