use utf8;
package XTracker::Schema::Result::WebContent::Type;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("web_content.type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "web_content.type_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("type_name_key", ["name"]);
__PACKAGE__->has_many(
  "pages",
  "XTracker::Schema::Result::WebContent::Page",
  { "foreign.type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "type_fields",
  "XTracker::Schema::Result::WebContent::TypeField",
  { "foreign.type_id" => "self.id" },
  undef,
);
__PACKAGE__->many_to_many("fields", "type_fields", "field");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:NVNa5QvUhHHpnzwpVDvXUg

1;
