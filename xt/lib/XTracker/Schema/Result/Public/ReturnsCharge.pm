use utf8;
package XTracker::Schema::Result::Public::ReturnsCharge;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.returns_charge");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "returns_charge_id_seq",
  },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "carrier_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "currency_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "charge",
  {
    data_type => "numeric",
    default_value => 0,
    is_nullable => 0,
    size => [10, 2],
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "returns_charge_channel_id_key",
  ["channel_id", "carrier_id", "country_id", "currency_id"],
);
__PACKAGE__->belongs_to(
  "carrier",
  "XTracker::Schema::Result::Public::Carrier",
  { id => "carrier_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
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
__PACKAGE__->belongs_to(
  "currency",
  "XTracker::Schema::Result::Public::Currency",
  { id => "currency_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6bypY5naXHTT+81quQwm1w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
