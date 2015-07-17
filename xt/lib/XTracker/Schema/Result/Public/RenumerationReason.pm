use utf8;
package XTracker::Schema::Result::Public::RenumerationReason;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.renumeration_reason");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "renumeration_reason_id_seq",
  },
  "renumeration_reason_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "reason",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "department_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "enabled",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "renumeration_reason_renumeration_reason_type_id_reason_key",
  ["renumeration_reason_type_id", "reason"],
);
__PACKAGE__->has_many(
  "bulk_reimbursements",
  "XTracker::Schema::Result::Public::BulkReimbursement",
  { "foreign.renumeration_reason_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "department",
  "XTracker::Schema::Result::Public::Department",
  { id => "department_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "renumeration_reason_type",
  "XTracker::Schema::Result::Public::RenumerationReasonType",
  { id => "renumeration_reason_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "renumerations",
  "XTracker::Schema::Result::Public::Renumeration",
  { "foreign.renumeration_reason_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1ZR8ggYmX3+FqWRVUtuKaQ


__PACKAGE__->belongs_to(
    'department' => 'Public::Department',
    { 'foreign.id' => 'self.department_id' },
    { 'join_type' => 'left' },
);

1;
