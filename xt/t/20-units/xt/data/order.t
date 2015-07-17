#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::RunCondition
    dc       => "DC1";


use XTracker::Database qw/get_schema_and_ro_dbh/;
use Test::XTracker::Data::Order;
use Test::XTracker::Data;
use XT::Data::Order;
use XT::Order::Parser;
use Test::XTracker::Data::Order::Parser::PublicWebsiteXML;
use Test::XTracker::Data;


note "* Setup";
Test::XTracker::Data::Order->purge_order_directories();

# Mock shipment_type, to avoid the hassle of getting the
# shipping_charge correct
no warnings "redefine";
local *XT::Data::Order::shipment_type = sub {
    my $self = shift;
    scalar @_ and $self->{__shipment_type} = $_[0];
    return $self->{__shipment_type};
};


my $order_file = 'OUTNET_INTL_regular_orders.xml.tt';
my $expected_channel_id = Test::XTracker::Data->channel_for_out->id;
my $order_parser = Test::XTracker::Data::Order::Parser::PublicWebsiteXML->new();
my $orders = $order_parser->parse_order_file($order_file);
ok(my $order = $orders->[0], "Got back at least one order");
# warn "Orders: " . Data::Dumper->new([$orders])->Maxdepth(4)->Dump(); use Data::Dumper;



note "* Tests";

sub test_shipping_account_name {
    my ($args) = @_;

    my ($schema, $dbh) = get_schema_and_ro_dbh('xtracker_schema');
    my $shipping_charge_rs = $schema->resultset("Public::ShippingCharge");
    my $shipment_type_rs = $schema->resultset("Public::ShipmentType");

    my $shipping_charge = $order->shipping_charge( # Only by default carrier for is_ground
        $shipping_charge_rs->search({ description => $args->{shipping_charge} })->first,
    );

    my $shipment_type = $order->shipment_type(
        $shipment_type_rs->search({ type => $args->{shipment_type} })->first,
    );


    no warnings "redefine";
    note "Setting virt vouchers only"                               if($args->{is_no_shipment});
    local *XT::Data::Order::_virtual_voucher_only_order = sub { 1 } if($args->{is_no_shipment}); ## no critic(ProtectPrivateVars)

    my $shipping_account = $order->shipping_account;
    ok(
        $shipping_account,
        "Got Shipping Account for Shipping Charge ($args->{shipping_charge}) and Shipment Type ($args->{shipment_type})" . ($args->{is_no_shipment} ? " No shipment" : ""),
    );
    if($shipping_account) {
        is(
            $shipping_account->name,
            $args->{expected_shipping_account},
            "  with the expected Shipping Account name ($args->{expected_shipping_account})",
        );

        my $shipping_account_id = $schema->resultset("Public::ShippingAccount")
            ->search({
                channel_id => $expected_channel_id,
                name       => $args->{expected_shipping_account},
        })->first->id;
        is(
            $shipping_account->id,
            $shipping_account_id,
            "  with the expected Shipping Account id ($shipping_account_id)",
        );
    }
}



# shipment_type
# 1 | Unknown
# 4 | International
# 5 | International DDU
# 3 | Domestic
# 2 | Premier

my $tests = [
    {
        shipping_charge           => "Germany",              # Not ground
        shipment_type             => "International",
        expected_shipping_account => "International",
    },
    {
        shipping_charge           => "Europe EU - Ground 1", # Ground
        shipment_type             => "International",
        expected_shipping_account => "International Road",
    },

    {
        shipping_charge           => "Germany",              # Not ground
        shipment_type             => "International DDU",
        expected_shipping_account => "International",
    },
    {
        shipping_charge           => "Europe EU - Ground 1", # Ground
        shipment_type             => "International DDU",
        expected_shipping_account => "International Road",
    },

    {
        shipping_charge           => "Germany",              # Not ground
        shipment_type             => "Domestic",
        expected_shipping_account => "Domestic",
    },

    ## SKIP: This combo exists, but doesn't make much sense; so don't
    ## mandate a behaviour

    # {
    #     shipping_charge           => "Europe EU - Ground 1", # Ground
    #     shipment_type             => "Domestic",
    #     expected_shipping_account => "Domestic",
    # },

    ## Unknown is currently a mixup of either Premier, or No-Shipment
    ## (like for virtual vouchers only). When that's straightened out,
    ## this will need changing
    # Premier
    {
        shipping_charge           => "Germany",              # Not ground
        shipment_type             => "Premier",
        expected_shipping_account => "Unknown",
    },
    {
        shipping_charge           => "Europe EU - Ground 1", # Ground
        shipment_type             => "Premier",
        expected_shipping_account => "Unknown",
    },
    # No-Shipment
    {
        is_no_shipment            => 1,
        shipping_charge           => "Germany",              # Not ground
        shipment_type             => "Domestic",
        expected_shipping_account => "Unknown",
    },
    {
        is_no_shipment            => 1,
        shipping_charge           => "Europe EU - Ground 1", # Ground
        shipment_type             => "Domestic",
        expected_shipping_account => "Unknown",
    },

];

for my $test (@$tests) {
    test_shipping_account_name($test);
}


done_testing;
