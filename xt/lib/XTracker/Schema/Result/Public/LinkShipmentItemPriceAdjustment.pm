use utf8;
package XTracker::Schema::Result::Public::LinkShipmentItemPriceAdjustment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_shipment_item__price_adjustment");
__PACKAGE__->add_columns(
  "shipment_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "price_adjustment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("shipment_item_id", "price_adjustment_id");
__PACKAGE__->add_unique_constraint("ship_item_adjustment", ["shipment_item_id"]);
__PACKAGE__->belongs_to(
  "price_adjustment",
  "XTracker::Schema::Result::Public::PriceAdjustment",
  { id => "price_adjustment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment_item",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { id => "shipment_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:W1+cw9nLpF4mVOcQap7Q8g


# You can replace this text with custom content, and it will be preserved on regeneration
1;
