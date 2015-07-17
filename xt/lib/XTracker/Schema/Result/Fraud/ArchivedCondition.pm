use utf8;
package XTracker::Schema::Result::Fraud::ArchivedCondition;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.archived_condition");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fraud.archived_condition_id_seq",
  },
  "rule_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "method_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "conditional_operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "enabled",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "change_log_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
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
__PACKAGE__->belongs_to(
  "change_log",
  "XTracker::Schema::Result::Fraud::ChangeLog",
  { id => "change_log_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "conditional_operator",
  "XTracker::Schema::Result::Fraud::ConditionalOperator",
  { id => "conditional_operator_id" },
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
  "method",
  "XTracker::Schema::Result::Fraud::Method",
  { id => "method_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "rule",
  "XTracker::Schema::Result::Fraud::ArchivedRule",
  { id => "rule_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:YdcDZ/idKvBPKBzAOrd6TA


use Moose;
with 'XTracker::Schema::Role::Result::FraudCondition';


1;
