use utf8;
package XTracker::Schema::Result::Public::RenumerationStatusLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.renumeration_status_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "renumeration_status_log_id_seq",
  },
  "renumeration_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "renumeration_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date",
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
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "renumeration",
  "XTracker::Schema::Result::Public::Renumeration",
  { id => "renumeration_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "renumeration_status",
  "XTracker::Schema::Result::Public::RenumerationStatus",
  { id => "renumeration_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KhpHUPUNxuWsoq5lrB7sZg

__PACKAGE__->belongs_to(
    'status' => 'Public::RenumerationStatus',
    { 'foreign.id' => 'self.renumeration_status_id' },
);

1;