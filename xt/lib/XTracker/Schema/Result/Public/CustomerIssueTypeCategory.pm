use utf8;
package XTracker::Schema::Result::Public::CustomerIssueTypeCategory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.customer_issue_type_category");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "customer_issue_type_category_id_seq",
  },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "description_visible",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "display_sequence",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "customer_issue_type_category_description_key",
  ["description"],
);
__PACKAGE__->has_many(
  "customer_issue_types",
  "XTracker::Schema::Result::Public::CustomerIssueType",
  { "foreign.category_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2rHemHv8URcNn0AllLus4g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
