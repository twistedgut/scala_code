use utf8;
package XTracker::Schema::Result::Public::PackLaneAttribute;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.pack_lane_attribute");
__PACKAGE__->add_columns(
  "pack_lane_attribute_id",
  { data_type => "integer", is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("pack_lane_attribute_id");
__PACKAGE__->add_unique_constraint("pack_lane_attribute_name_key", ["name"]);
__PACKAGE__->has_many(
  "pack_lanes_has_attributes",
  "XTracker::Schema::Result::Public::PackLaneHasAttribute",
  {
    "foreign.pack_lane_attribute_id" => "self.pack_lane_attribute_id",
  },
  undef,
);
__PACKAGE__->many_to_many("pack_lanes", "pack_lanes_has_attributes", "pack_lane");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:UExYIxB6UQyaw5k5HDBR5A

1;
