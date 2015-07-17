use utf8;
package XTracker::Schema::Result::Public::VertexArea;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.vertex_area");
__PACKAGE__->add_columns(
  "country",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "county",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->add_unique_constraint("vertex_area_country_county_key", ["country", "county"]);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+50AWnYPUzeXvYLKErUt5Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
