use utf8;
package XTracker::Schema::Result::Public::CustomerIssueType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.customer_issue_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "customer_issue_type_id_seq",
  },
  "group_id",
  { data_type => "smallint", is_foreign_key => 1, is_nullable => 1 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 512 },
  "pws_reason",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "category_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "display_sequence",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "enabled",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("customer_issue_type_description_idx", ["description"]);
__PACKAGE__->has_many(
  "cancelled_items",
  "XTracker::Schema::Result::Public::CancelledItem",
  { "foreign.customer_issue_type_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "category",
  "XTracker::Schema::Result::Public::CustomerIssueTypeCategory",
  { id => "category_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "customer_issue_type_group",
  "XTracker::Schema::Result::Public::CustomerIssueTypeGroup",
  { id => "group_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "return_items",
  "XTracker::Schema::Result::Public::ReturnItem",
  { "foreign.customer_issue_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8gwKrmFLxZnZfMsssngx9Q

__PACKAGE__->belongs_to(
    'customer_issue_type_group' => 'Public::CustomerIssueTypeGroup',
    { 'foreign.id' => 'self.group_id' },
);
1;
