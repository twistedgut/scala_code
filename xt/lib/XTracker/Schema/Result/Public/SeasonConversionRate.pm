use utf8;
package XTracker::Schema::Result::Public::SeasonConversionRate;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.season_conversion_rate");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "season_conversion_rate_id_seq",
  },
  "season_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "source_currency_id",
  { data_type => "integer", is_nullable => 0 },
  "destination_currency_id",
  { data_type => "integer", is_nullable => 0 },
  "conversion_rate",
  { data_type => "double precision", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "season_conversion_rate_season_id_key",
  ["season_id", "source_currency_id", "destination_currency_id"],
);
__PACKAGE__->belongs_to(
  "season",
  "XTracker::Schema::Result::Public::Season",
  { id => "season_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LwFNrRbzdsR/POVRDzhuXw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
