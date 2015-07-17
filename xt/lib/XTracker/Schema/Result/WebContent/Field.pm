use utf8;
package XTracker::Schema::Result::WebContent::Field;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("web_content.field");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "web_content.field_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 45 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("field_name_key", ["name"]);
__PACKAGE__->has_many(
  "contents",
  "XTracker::Schema::Result::WebContent::Content",
  { "foreign.field_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "type_fields",
  "XTracker::Schema::Result::WebContent::TypeField",
  { "foreign.field_id" => "self.id" },
  undef,
);
__PACKAGE__->many_to_many("types", "type_fields", "type");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BvI+y5Wqv/lU3Km4BiRbOQ

1;
