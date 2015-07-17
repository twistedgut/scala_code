use utf8;
package XTracker::Schema::Result::Fraud::OrdersRuleOutcome;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.orders_rule_outcome");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fraud.orders_rule_outcome_id_seq",
  },
  "orders_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "archived_rule_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "finance_flag_ids",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "textualisation",
  { data_type => "text", is_nullable => 0 },
  "rule_outcome_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("orders_rule_outcome_orders_id_key", ["orders_id"]);
__PACKAGE__->belongs_to(
  "archived_rule",
  "XTracker::Schema::Result::Fraud::ArchivedRule",
  { id => "archived_rule_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "orders",
  "XTracker::Schema::Result::Public::Orders",
  { id => "orders_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "rule_outcome_status",
  "XTracker::Schema::Result::Fraud::RuleOutcomeStatus",
  { id => "rule_outcome_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZUZXlf0Z86dvttlaMdbmGw

1;
