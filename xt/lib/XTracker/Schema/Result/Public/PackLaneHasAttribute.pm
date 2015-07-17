use utf8;
package XTracker::Schema::Result::Public::PackLaneHasAttribute;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.pack_lane_has_attribute");
__PACKAGE__->add_columns(
  "pack_lane_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pack_lane_attribute_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("pack_lane_id", "pack_lane_attribute_id");
__PACKAGE__->belongs_to(
  "attribute",
  "XTracker::Schema::Result::Public::PackLaneAttribute",
  { pack_lane_attribute_id => "pack_lane_attribute_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "pack_lane",
  "XTracker::Schema::Result::Public::PackLane",
  { pack_lane_id => "pack_lane_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/hU8P8Xc0ZeOkEIemSZWAQ

1;
