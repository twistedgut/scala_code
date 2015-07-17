use utf8;
package XTracker::Schema::Result::Public::FilterColourMapping;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.filter_colour_mapping");
__PACKAGE__->add_columns(
  "colour_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "filter_colour_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("colour_id");
__PACKAGE__->belongs_to(
  "colour",
  "XTracker::Schema::Result::Public::Colour",
  { id => "colour_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "filter_colour",
  "XTracker::Schema::Result::Public::ColourFilter",
  { id => "filter_colour_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ObvfmYqq4+3gf7FBmYj+WQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
