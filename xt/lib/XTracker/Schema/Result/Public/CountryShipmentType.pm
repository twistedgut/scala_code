use utf8;
package XTracker::Schema::Result::Public::CountryShipmentType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.country_shipment_type");
__PACKAGE__->add_columns(
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipment_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "auto_ddu",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->add_unique_constraint("channel_id_country_id_key", ["channel_id", "country_id"]);
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
  "shipment_type",
  "XTracker::Schema::Result::Public::ShipmentType",
  { id => "shipment_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:E7OLkH4rENxkQJtIN8iK8A

__PACKAGE__->belongs_to(
  "shipment_type",
  "XTracker::Schema::Result::Public::ShipmentType",
  { id => "shipment_type_id" },
  {},
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
