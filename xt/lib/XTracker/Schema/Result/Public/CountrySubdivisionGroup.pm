use utf8;
package XTracker::Schema::Result::Public::CountrySubdivisionGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.country_subdivision_group");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "country_subdivision_group_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 128 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("country_subdivision_group_name_key", ["name"]);
__PACKAGE__->has_many(
  "country_subdivisions",
  "XTracker::Schema::Result::Public::CountrySubdivision",
  { "foreign.country_subdivision_group_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:D3nubBi1qAyhxDf4Ep5kNw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
