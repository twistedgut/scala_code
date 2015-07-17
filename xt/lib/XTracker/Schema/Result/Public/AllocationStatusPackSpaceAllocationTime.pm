use utf8;
package XTracker::Schema::Result::Public::AllocationStatusPackSpaceAllocationTime;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.allocation_status_pack_space_allocation_time");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "allocation_status_pack_space_allocation_time_id_seq",
  },
  "allocation_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "prl_pack_space_allocation_time_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_pack_space_allocated",
  { data_type => "boolean", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "unique_allocation_status_id_prl_pack_space_allocation_time_id",
  ["allocation_status_id", "prl_pack_space_allocation_time_id"],
);
__PACKAGE__->belongs_to(
  "allocation_status",
  "XTracker::Schema::Result::Public::AllocationStatus",
  { id => "allocation_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "prl_pack_space_allocation_time",
  "XTracker::Schema::Result::Public::PrlPackSpaceAllocationTime",
  { id => "prl_pack_space_allocation_time_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7WxdgLrduyd6b0o5TeuYTw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
