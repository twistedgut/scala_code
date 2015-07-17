#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use FindBin::libs;



use aliased 'XT::Order::ImportUtils' => 'IU';
use XTracker::Config::Local qw( config_var );

# pick a random order
my $waiting_dir = config_var('SystemPaths', 'xmlwaiting_dir');
my @files = glob("$waiting_dir/*.xml");

unless (@files) {
    plan skip_all => "There are no orders waiting to test against";
}

my $path = $files[rand @files];

# utility!
my $util = IU->new();

# test dbh
isa_ok( $util->dbh, 'DBI::db');

# test parser
isa_ok( $util->parser, 'XML::LibXML');
my $doc = $util->parse_order_file($path);

# test document
isa_ok( $doc, 'XML::LibXML::Document');
cmp_ok( $doc->documentElement()->nodeName(),
        'eq',
        'ORDERS',
        'The root node is \'ORDERS\'' );

# test orders
is(@{$util->order_elements($doc)},
   1,
  'The number of orders in the doc is 1');

foreach my $order_node ($util->order_elements($doc)){

    my $order_data = $util->order_data($order_node);

    isa_ok($order_data, 'HASH');
}

done_testing;
