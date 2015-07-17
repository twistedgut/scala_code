#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use XTracker::Database qw/get_schema_and_ro_dbh/;
use Test::XTracker::Data::Order::Parser::PublicWebsiteXML;

# delete all existing xml files in case of previously crashed test:
Test::XTracker::Data::Order->purge_order_directories();

BEGIN { use_ok( 'XT::Order::Parser' ); }
require_ok( 'XT::Order::Parser' );

BEGIN { use_ok( 'XT::Data::Order' ); }
require_ok( 'XT::Data::Order' );

my $order_file = 'NAP_INTL_orders_percentage_off.xml.tt';
my $order_parser = Test::XTracker::Data::Order::Parser::PublicWebsiteXML->new();
my $order_xml  = $order_parser->slurp_order_xml($order_file);

my ( $schema, $dbh ) = get_schema_and_ro_dbh('xtracker_schema');

my $parser = XT::Order::Parser->new_parser({
    schema  => $schema,
    data    => $order_xml
});
isa_ok( $parser, 'XT::Order::Parser::PublicWebsiteXML' );

my $orders = $parser->parse;
ok( @{$orders} > 0, 'Got some orders...');
SKIP: {
    skip "Either ensure product exists or delete test", 2;
    foreach ( @{$orders} ) {
        isa_ok( $_, 'XT::Data::Order' );
        $_->digest;
        ok( Test::XTracker::Data::Order->does_order_exist( $_ ),
            'Order was stored in database' );
    }
}

done_testing;

