use utf8;
package XTracker::Schema::Result::Fraud::ArchivedList;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.archived_list");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fraud.archived_list_id_seq",
  },
  "list_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 50 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "change_log_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "created_by_operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "expired",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "expired_by_operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "archived_list_items",
  "XTracker::Schema::Result::Fraud::ArchivedListItem",
  { "foreign.list_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "change_log",
  "XTracker::Schema::Result::Fraud::ChangeLog",
  { id => "change_log_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "created_by_operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "created_by_operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "expired_by_operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "expired_by_operator_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "list_type",
  "XTracker::Schema::Result::Fraud::ListType",
  { id => "list_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "live_lists",
  "XTracker::Schema::Result::Fraud::LiveList",
  { "foreign.archived_list_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zVqxmUY7ruEoqNoqQSw46A

__PACKAGE__->has_many(
  "list_items",
  "XTracker::Schema::Result::Fraud::ArchivedListItem",
  { "foreign.list_id" => "self.id" },
  {},
);

1;
