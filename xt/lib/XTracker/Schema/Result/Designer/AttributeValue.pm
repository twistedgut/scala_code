use utf8;
package XTracker::Schema::Result::Designer::AttributeValue;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("designer.attribute_value");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "designer.attribute_value_id_seq",
  },
  "designer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "attribute_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "sort_order",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "deleted",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "attribute_value_designer_id_key",
  ["designer_id", "attribute_id"],
);
__PACKAGE__->belongs_to(
  "attribute",
  "XTracker::Schema::Result::Designer::Attribute",
  { id => "attribute_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "designer",
  "XTracker::Schema::Result::Public::Designer",
  { id => "designer_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "log_attribute_values",
  "XTracker::Schema::Result::Designer::LogAttributeValue",
  { "foreign.attribute_value_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+9sPIMBOGpb+GDVVN8IcOw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
