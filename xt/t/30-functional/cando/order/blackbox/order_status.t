#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::Most '-Test::Deep';
use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::XTracker::PrintDocs;

use Test::XTracker::Data::Order::Parser::PublicWebsiteXML;
use XTracker::Constants::FromDB     qw( :business );

use Test::XTracker::RunCondition
    export    => [qw( $iws_rollout_phase $prl_rollout_phase )];

my $mech = Test::XTracker::Mechanize->new;
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::PRL',
    ],
    mech => $mech,
);

my (undef,$pids) = Test::XTracker::Data->grab_products({
    how_many => 1,
    channel => 'nap',
});

my $PID = $pids->[0]{pid};
my $SIZE = $pids->[0]{size_id};

# In case previous tests left bad files
Test::XTracker::Data::Order->purge_order_directories();

my $xml_parser = Test::XTracker::Data::Order::Parser::PublicWebsiteXML->new();
my $channel    = $mech->schema->resultset('Public::Business')->find($BUSINESS__NAP)->channels->first;

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
my $order_nr = $order->order_nr;

Test::XTracker::Data->ensure_stock($PID, $SIZE);

note $order_nr;

Test::XTracker::Data::Order->allocate_order($order);

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
diag "Shipment Nr: $ship_nr" if $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE};

# The order status might be Credit Hold. Check and fix if needed
if ($status eq "Credit Hold") {
  Test::XTracker::Data->set_department('it.god', 'Finance');
  $mech->reload;
  $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
  ($ship_nr, $status, $category) = gather_order_info();
}
is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

my $print_directory = Test::XTracker::PrintDocs->new();

my $skus = $mech->get_order_skus();

if ($prl_rollout_phase) {
    Test::XTracker::Data::Order->allocate_order($order);
    Test::XTracker::Data::Order->select_order($order);
    my $container_id = Test::XT::Data::Container->get_unique_id({ how_many => 1 });
    $framework->flow_msg__prl__pick_shipment(
        shipment_id => $order->shipments->first->id,
        container => {
            $container_id => [keys %$skus],
        }
    );
    $framework->flow_msg__prl__induct_shipment(
        shipment_row => $order->shipments->first,
    );
} else {
    # Get the location from the picking list
    $mech->test_select_order($category,$ship_nr);
    $skus   = $mech->get_info_from_picklist($print_directory,$skus) if $iws_rollout_phase == 0;
    $mech->test_pick_shipment( $ship_nr, $skus );
}

$mech->test_pack_shipment($ship_nr, $skus);
$mech->test_assign_airway_bill($ship_nr);
$mech->test_dispatch($ship_nr);

# TODO We expect some files from the above tests: these tests should check them
my @unexpected_files =
    grep { $_->file_type !~ /^(invoice|matchup_sheet|outpro|retpro|shippingform|dgn)$/ }
    $print_directory->new_files();

ok(!@unexpected_files, 'should not have any unexpected print files');

Test::XTracker::Data::Order->purge_order_directories();

done_testing;


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

