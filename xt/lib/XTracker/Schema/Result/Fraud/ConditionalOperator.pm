use utf8;
package XTracker::Schema::Result::Fraud::ConditionalOperator;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.conditional_operator");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fraud.conditional_operator_id_seq",
  },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "symbol",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "perl_operator",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "is_list_operator",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "archived_conditions",
  "XTracker::Schema::Result::Fraud::ArchivedCondition",
  { "foreign.conditional_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_return_value_type__conditional_operators",
  "XTracker::Schema::Result::Fraud::LinkReturnValueTypeConditionalOperator",
  { "foreign.conditional_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "live_conditions",
  "XTracker::Schema::Result::Fraud::LiveCondition",
  { "foreign.conditional_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "staging_conditions",
  "XTracker::Schema::Result::Fraud::StagingCondition",
  { "foreign.conditional_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->many_to_many(
  "return_value_types",
  "link_return_value_type__conditional_operators",
  "return_value_type",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:JTDogdaQ1Up4Rb6b94n95g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
