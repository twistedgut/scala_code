use utf8;
package XTracker::Schema::Result::Public::ColourFilter;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.colour_filter");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "colour_filter_id_seq",
  },
  "colour_filter",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("colour_filter_colour_filter_idx", ["colour_filter"]);
__PACKAGE__->has_many(
  "filter_colour_mappings",
  "XTracker::Schema::Result::Public::FilterColourMapping",
  { "foreign.filter_colour_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "products",
  "XTracker::Schema::Result::Public::Product",
  { "foreign.colour_filter_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CHFqrRVKq0qqbAeyvDXiBQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
