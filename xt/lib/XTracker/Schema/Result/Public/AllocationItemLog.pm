use utf8;
package XTracker::Schema::Result::Public::AllocationItemLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.allocation_item_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "allocation_item_log_id_seq",
  },
  "date",
  {
    data_type     => "timestamp with time zone",
    default_value => \"statement_timestamp()",
    is_nullable   => 0,
  },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "allocation_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "allocation_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "allocation_item_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "allocation_item",
  "XTracker::Schema::Result::Public::AllocationItem",
  { id => "allocation_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "allocation_item_status",
  "XTracker::Schema::Result::Public::AllocationItemStatus",
  { id => "allocation_item_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "allocation_status",
  "XTracker::Schema::Result::Public::AllocationStatus",
  { id => "allocation_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0W9R9YrDfsriWEFYQhOdlQ

1;
