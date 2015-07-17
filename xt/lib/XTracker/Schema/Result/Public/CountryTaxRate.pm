use utf8;
package XTracker::Schema::Result::Public::CountryTaxRate;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.country_tax_rate");
__PACKAGE__->add_columns(
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "tax_name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "rate",
  {
    data_type => "numeric",
    default_value => "0.000",
    is_nullable => 0,
    size => [10, 3],
  },
);
__PACKAGE__->set_primary_key("country_id");
__PACKAGE__->belongs_to(
  "country",
  "XTracker::Schema::Result::Public::Country",
  { id => "country_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:z5q96k/Fk2V86XGRsbdzrw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
