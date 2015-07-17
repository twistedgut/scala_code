use utf8;
package XTracker::Schema::Result::Flow::NextStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("flow.next_status");
__PACKAGE__->add_columns(
  "current_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "next_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("current_status_id", "next_status_id");
__PACKAGE__->belongs_to(
  "current_status",
  "XTracker::Schema::Result::Flow::Status",
  { id => "current_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "next_status",
  "XTracker::Schema::Result::Flow::Status",
  { id => "next_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:v+l512SR5CibRSmpRXJHqA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
