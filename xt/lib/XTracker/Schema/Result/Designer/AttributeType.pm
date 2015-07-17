use utf8;
package XTracker::Schema::Result::Designer::AttributeType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("designer.attribute_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "designer.attribute_type_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "web_attribute",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "navigational",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("attribute_type_name_key", ["name"]);
__PACKAGE__->has_many(
  "attribute",
  "XTracker::Schema::Result::Designer::Attribute",
  { "foreign.attribute_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:E3vP1rkpntVii4SuBssiPw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
