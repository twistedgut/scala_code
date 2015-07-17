#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

#
# Basic functionality tests for Containers
#
#  make sure we can:
#
#   + pick an item into an empty (perhaps non-existent) container
#   + pick further items into a non-empty container that contains
#     only picked items
#   + fail to pick into a container whose capacity has been reached
#   + remove a picked item from a container
#   + pick items into a non-empty container that contains
#     only picked items
#




# evil globals
our ($schema);

BEGIN {
    use_ok('XTracker::Schema');
    use_ok('XTracker::Database',':common');
    use_ok('XTracker::Handler');
}

# get a schema to query
$schema = get_database_handle(
    {
        name    => 'xtracker_schema',
    }
);
isa_ok($schema, 'XTracker::Schema',"Schema Created");

my $c_rs = $schema->resultset('Public::Container');
isa_ok($c_rs, 'XTracker::Schema::ResultSet::Public::Container',"Container Result Set");

# check methods that exist on the resultset
can_ok(
    'XTracker::Schema::Result::Public::Container',
    qw[
          set_status
          add_picked_item
          add_packing_exception_item
          add_picked_shipment
          remove_shipment
          remove_item
          is_empty
          shipment_ids
          shipments
          is_multi_shipment
          get_channel
    ]
);



done_testing;
