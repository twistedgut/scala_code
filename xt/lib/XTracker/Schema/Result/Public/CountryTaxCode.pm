use utf8;
package XTracker::Schema::Result::Public::CountryTaxCode;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.country_tax_code");
__PACKAGE__->add_columns(
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "code",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->add_unique_constraint(
  "channel_id_country_id_tax_code_key",
  ["channel_id", "country_id"],
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "country",
  "XTracker::Schema::Result::Public::Country",
  { id => "country_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ntsk3lWBjmclRh4u3yNvTA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
