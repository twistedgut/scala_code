use utf8;
package XTracker::Schema::Result::Public::CountrySubdivision;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.country_subdivision");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "country_subdivision_id_seq",
  },
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "iso",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 128 },
  "country_subdivision_group_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("country_subdivision_name_key", ["name"]);
__PACKAGE__->belongs_to(
  "country",
  "XTracker::Schema::Result::Public::Country",
  { id => "country_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "country_subdivision_group",
  "XTracker::Schema::Result::Public::CountrySubdivisionGroup",
  { id => "country_subdivision_group_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3sBqeyUswDtfHs/ZvHYeCg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
