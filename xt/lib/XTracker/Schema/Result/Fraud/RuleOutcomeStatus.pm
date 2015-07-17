use utf8;
package XTracker::Schema::Result::Fraud::RuleOutcomeStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.rule_outcome_status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fraud.rule_outcome_status_id_seq",
  },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("rule_outcome_status_status_key", ["status"]);
__PACKAGE__->has_many(
  "orders_rule_outcomes",
  "XTracker::Schema::Result::Fraud::OrdersRuleOutcome",
  { "foreign.rule_outcome_status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/fYEc3G8k31MiVXBbHeAtg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
