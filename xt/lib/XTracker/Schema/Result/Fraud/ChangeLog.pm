use utf8;
package XTracker::Schema::Result::Fraud::ChangeLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.change_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fraud.change_log_id_seq",
  },
  "description",
  { data_type => "text", is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "archived_conditions",
  "XTracker::Schema::Result::Fraud::ArchivedCondition",
  { "foreign.change_log_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "archived_lists",
  "XTracker::Schema::Result::Fraud::ArchivedList",
  { "foreign.change_log_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "archived_rules",
  "XTracker::Schema::Result::Fraud::ArchivedRule",
  { "foreign.change_log_id" => "self.id" },
  undef,
);
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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aLxzbpmSYkH2tZqAD2vnJw


1;
