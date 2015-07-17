use utf8;
package XTracker::Schema::Result::Audit::Recent;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("audit.recent");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "audit.recent_id_seq",
  },
  "table_schema",
  { data_type => "text", is_nullable => 0 },
  "table_name",
  { data_type => "text", is_nullable => 0 },
  "col_name",
  { data_type => "text", is_nullable => 0 },
  "col_type",
  { data_type => "text", is_nullable => 0 },
  "audit_id",
  { data_type => "integer", is_nullable => 0 },
  "descriptor",
  { data_type => "text", is_nullable => 1 },
  "descriptor_value",
  { data_type => "text", is_nullable => 1 },
  "old_val",
  { data_type => "text", is_nullable => 1 },
  "new_val",
  { data_type => "text", is_nullable => 1 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "timestamp",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:giULDdwquUFOXTXP2T9p5A


1;
