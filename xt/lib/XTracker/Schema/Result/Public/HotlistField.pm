use utf8;
package XTracker::Schema::Result::Public::HotlistField;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.hotlist_field");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "hotlist_field_id_seq",
  },
  "hotlist_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "field",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "hotlist_type",
  "XTracker::Schema::Result::Public::HotlistType",
  { id => "hotlist_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "hotlist_values",
  "XTracker::Schema::Result::Public::HotlistValue",
  { "foreign.hotlist_field_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sFovjUf0bCJw8qlkDJcayw

# You can replace this text with custom code or comments, and it will be preserved on regeneration

1;
