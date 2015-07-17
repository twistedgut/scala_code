use utf8;
package XTracker::Schema::Result::Public::LinkDeliveryItemStockOrderItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_delivery_item__stock_order_item");
__PACKAGE__->add_columns(
  "delivery_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "stock_order_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("delivery_item_id", "stock_order_item_id");
__PACKAGE__->belongs_to(
  "delivery_item",
  "XTracker::Schema::Result::Public::DeliveryItem",
  { id => "delivery_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "stock_order_item",
  "XTracker::Schema::Result::Public::StockOrderItem",
  { id => "stock_order_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2/FB61n9OLoj++Ra0xF8qg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
