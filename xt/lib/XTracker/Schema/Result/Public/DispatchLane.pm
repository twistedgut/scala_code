use utf8;
package XTracker::Schema::Result::Public::DispatchLane;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.dispatch_lane");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dispatch_lane_id_seq",
  },
  "lane_nr",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("dispatch_lane_lane_nr_unique", ["lane_nr"]);
__PACKAGE__->has_many(
  "link_shipment_type__dispatch_lanes",
  "XTracker::Schema::Result::Public::LinkShipmentTypeDispatchLane",
  { "foreign.dispatch_lane_id" => "self.id" },
  undef,
);
__PACKAGE__->many_to_many(
  "shipment_types",
  "link_shipment_type__dispatch_lanes",
  "shipment_type",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:V6CHd9kbQeYJ59NXzJr0pg

# Ensure resultset is sorted by lane number, so lanes appear in a consistent
# and logical order. Otherwise, deleting and reinserting a lane will change its
# order in the round-robin, which is probably not desired behaviour!
__PACKAGE__->resultset_attributes({ order_by => 'lane_nr' });

1;
