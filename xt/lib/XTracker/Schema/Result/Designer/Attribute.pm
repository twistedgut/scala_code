use utf8;
package XTracker::Schema::Result::Designer::Attribute;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("designer.attribute");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "designer.attribute_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "attribute_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "deleted",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "synonyms",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "manual_sort",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "page_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "attribute_name_key",
  ["name", "attribute_type_id", "channel_id"],
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "designer_attribute",
  "XTracker::Schema::Result::Designer::AttributeValue",
  { "foreign.attribute_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "page",
  "XTracker::Schema::Result::WebContent::Page",
  { id => "page_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::Designer::AttributeType",
  { id => "attribute_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sZ/dOkcgNY6p0kBtIN0PUQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
