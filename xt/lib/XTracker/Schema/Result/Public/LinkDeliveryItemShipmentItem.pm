use utf8;
package XTracker::Schema::Result::Public::LinkDeliveryItemShipmentItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_delivery_item__shipment_item");
__PACKAGE__->add_columns(
  "delivery_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipment_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("delivery_item_id", "shipment_item_id");
__PACKAGE__->belongs_to(
  "delivery_item",
  "XTracker::Schema::Result::Public::DeliveryItem",
  { id => "delivery_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment_item",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { id => "shipment_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:L7AOlwsKydhOzH/ZgWnFuA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
