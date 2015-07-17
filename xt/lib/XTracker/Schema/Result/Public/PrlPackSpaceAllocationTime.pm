use utf8;
package XTracker::Schema::Result::Public::PrlPackSpaceAllocationTime;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.prl_pack_space_allocation_time");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "display_name",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "allocation_status_pack_space_allocation_times",
  "XTracker::Schema::Result::Public::AllocationStatusPackSpaceAllocationTime",
  { "foreign.prl_pack_space_allocation_time_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "prls",
  "XTracker::Schema::Result::Public::Prl",
  { "foreign.prl_pack_space_allocation_time_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fjxBk+iQD2+JT0suPykfkQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
