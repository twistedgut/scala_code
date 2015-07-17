use utf8;
package XTracker::Schema::Result::Fraud::LinkReturnValueTypeConditionalOperator;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.link_return_value_type__conditional_operator");
__PACKAGE__->add_columns(
  "return_value_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "conditional_operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("return_value_type_id", "conditional_operator_id");
__PACKAGE__->belongs_to(
  "conditional_operator",
  "XTracker::Schema::Result::Fraud::ConditionalOperator",
  { id => "conditional_operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "return_value_type",
  "XTracker::Schema::Result::Fraud::ReturnValueType",
  { id => "return_value_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:bo3Wg0thDXwExCn/a7g6Tg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
