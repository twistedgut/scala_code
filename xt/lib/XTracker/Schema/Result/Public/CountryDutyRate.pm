use utf8;
package XTracker::Schema::Result::Public::CountryDutyRate;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.country_duty_rate");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "country_duty_rate_id_seq",
  },
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "hs_code_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "rate",
  {
    data_type => "numeric",
    default_value => "0.000",
    is_nullable => 0,
    size => [10, 3],
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("country_id_hs_code_id", ["country_id", "hs_code_id"]);
__PACKAGE__->belongs_to(
  "country",
  "XTracker::Schema::Result::Public::Country",
  { id => "country_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "hs_code",
  "XTracker::Schema::Result::Public::HSCode",
  { id => "hs_code_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:07KhWnoWj6+z2Tuef93iBw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
