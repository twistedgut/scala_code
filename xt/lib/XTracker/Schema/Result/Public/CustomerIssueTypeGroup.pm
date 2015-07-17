use utf8;
package XTracker::Schema::Result::Public::CustomerIssueTypeGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.customer_issue_type_group");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "customer_issue_type_group_id_seq",
  },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 512 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "customer_issue_types",
  "XTracker::Schema::Result::Public::CustomerIssueType",
  { "foreign.group_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KseMJ+i8K2nZvzRKBWQHfw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
