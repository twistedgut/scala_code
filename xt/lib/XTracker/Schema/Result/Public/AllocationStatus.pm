use utf8;
package XTracker::Schema::Result::Public::AllocationStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.allocation_status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "allocation_status_id_seq",
  },
  "status",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "description",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("allocation_status_status_key", ["status"]);
__PACKAGE__->has_many(
  "allocation_item_logs",
  "XTracker::Schema::Result::Public::AllocationItemLog",
  { "foreign.allocation_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "allocation_status_pack_space_allocation_times",
  "XTracker::Schema::Result::Public::AllocationStatusPackSpaceAllocationTime",
  { "foreign.allocation_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "allocations",
  "XTracker::Schema::Result::Public::Allocation",
  { "foreign.status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xYmkexNrDgEyuR8offoWYA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
