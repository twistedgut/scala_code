use utf8;
package XTracker::Schema::Result::Fraud::ReturnValueType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.return_value_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fraud.return_value_type_id_seq",
  },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "regex",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("return_value_type_type_key", ["type"]);
__PACKAGE__->has_many(
  "link_return_value_type__conditional_operators",
  "XTracker::Schema::Result::Fraud::LinkReturnValueTypeConditionalOperator",
  { "foreign.return_value_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "methods",
  "XTracker::Schema::Result::Fraud::Method",
  { "foreign.return_value_type_id" => "self.id" },
  undef,
);
__PACKAGE__->many_to_many(
  "conditional_operators",
  "link_return_value_type__conditional_operators",
  "conditional_operator",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:X+kvveGDgkoZV7d7i+Swrg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
