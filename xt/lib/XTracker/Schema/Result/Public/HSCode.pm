use utf8;
package XTracker::Schema::Result::Public::HSCode;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.hs_code");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "hs_code_id_seq",
  },
  "hs_code",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "active",
  { data_type => "boolean", default_value => \"true", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "country_duty_rates",
  "XTracker::Schema::Result::Public::CountryDutyRate",
  { "foreign.hs_code_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "products",
  "XTracker::Schema::Result::Public::Product",
  { "foreign.hs_code_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Zr33lYEMFS//zc5kXYnO9g


# You can replace this text with custom content, and it will be preserved on regeneration
1;
