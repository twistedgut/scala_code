use utf8;
package XTracker::Schema::Result::WebContent::TypeField;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("web_content.type_field");
__PACKAGE__->add_columns(
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "field_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("type_id", "field_id");
__PACKAGE__->belongs_to(
  "field",
  "XTracker::Schema::Result::WebContent::Field",
  { id => "field_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::WebContent::Type",
  { id => "type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qDKvDe60l2aDpQ/6hTVXxA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
