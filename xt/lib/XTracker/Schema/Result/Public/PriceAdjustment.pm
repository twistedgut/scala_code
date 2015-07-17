use utf8;
package XTracker::Schema::Result::Public::PriceAdjustment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.price_adjustment");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "price_adjustment_id_seq",
  },
  "product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "percentage",
  { data_type => "numeric", is_nullable => 0, size => [10, 2] },
  "date_start",
  { data_type => "timestamp", is_nullable => 0 },
  "exported",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "date_finish",
  {
    data_type     => "timestamp",
    default_value => "2100-01-01 00:00:00",
    is_nullable   => 1,
  },
  "category_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("price_adj_product", ["product_id", "date_finish"]);
__PACKAGE__->belongs_to(
  "category",
  "XTracker::Schema::Result::Public::PriceAdjustmentCategory",
  { id => "category_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "link_shipment_item__price_adjustments",
  "XTracker::Schema::Result::Public::LinkShipmentItemPriceAdjustment",
  { "foreign.price_adjustment_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "product",
  "XTracker::Schema::Result::Public::Product",
  { id => "product_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:We6mB1PKhtoqFr+kIteYTA

__PACKAGE__->many_to_many(
  "shipment_items",
  "link_shipment_item__price_adjustments",
  "shipment_item",
);

1;
