use utf8;
package XTracker::Schema::Result::Public::Colour;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.colour");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "colour_id_seq",
  },
  "colour",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->might_have(
  "filter_colour_mapping",
  "XTracker::Schema::Result::Public::FilterColourMapping",
  { "foreign.colour_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "products",
  "XTracker::Schema::Result::Public::Product",
  { "foreign.colour_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fnm0EoQedwkQWX7D3Vhm3w

# You can replace this text with custom content, and it will be preserved on regeneration
1;
