#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::RunCondition
    dc       => 'DC2',
    database => 'full';


use XTracker::Database          qw(get_schema_and_ro_dbh);
use Test::XTracker::Data::Order;
use Test::XTracker::Data::Order::Parser::PublicWebsiteXML;
use Test::XTracker::Data;
use XT::Data::Order;
use XT::Order::Parser;
use Data::Dumper;

Test::XTracker::Data::Order->purge_order_directories();

# Mock shipment_type, to avoid the hassle of getting the
# shipping_charge correct
no warnings 'redefine';
local *XT::Data::Order::shipment_type = sub {
    my $self = shift;
    scalar @_ and $self->{__shipment_type} = $_[0];
    return $self->{__shipment_type};
};
use warnings 'all';

my $order_file = 'OUTNET_AM_regular_orders.xml.tt';

my $tests = [
    {
        shipment_type    => 'International DDU',
        shipment_country => 'Albania',
    },
    {
        shipment_type    => 'International DDU',
        shipment_country => 'Hong Kong',
    },
];

foreach my $test ( @{ $tests } ) {
    my $order_parser = Test::XTracker::Data::Order::Parser::PublicWebsiteXML->new();
    my $orders = $order_parser->parse_order_file($order_file);
    ok( my $order = $orders->[0], 'Got back at least one order' );

    my ( $schema, $dbh )    = get_schema_and_ro_dbh( 'xtracker_schema' );
    my $shipment_type_rs    = $schema->resultset( 'Public::ShipmentType' );
    my $shipment_country_rs = $schema->resultset( 'Public::Country' );

    my $shipment_country    = $shipment_country_rs->search( { country => $test->{shipment_country} } )->first();
    $order->shipment_type( $shipment_type_rs->search( { type => $test->{shipment_type} } )->first() );
    $order->delivery_address()->country()->country( $shipment_country->country() );
    $order->delivery_address()->country_code( $shipment_country->code() );

    # this will check _check_ddu_acceptance
    eval { $order->digest(); };
    is( $@, '', 'No warnings on delivery' );
}

done_testing;
