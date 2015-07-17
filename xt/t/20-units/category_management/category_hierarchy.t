#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::XTracker::Data;
our ($schema, $rs);

# evil globals
BEGIN {

    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Schema');
    use_ok('XTracker::Schema::Result::Product::NavigationTree');
    use_ok('XTracker::Schema::Result::Product::NavigationTreeLock');
    use_ok('XTracker::DB::Factory::ProductNavigation');

    # get a schema to query
    $schema = get_database_handle(
        {
            name    => 'xtracker_schema',
        }
    );
    isa_ok($schema, 'XTracker::Schema');
}

my $factory = XTracker::DB::Factory::ProductNavigation->new(
    {
        schema => $schema
    }
);

can_ok(
    $factory,
    qw[
          get_attribute_nodes
          set_sort_order
          create_node
          delete_node
          set_node_visibility
          set_node_parent
    ]
);

done_testing;
