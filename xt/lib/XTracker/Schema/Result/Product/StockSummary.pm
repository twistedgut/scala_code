use utf8;
package XTracker::Schema::Result::Product::StockSummary;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("product.stock_summary");
__PACKAGE__->add_columns(
  "product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "ordered",
  { data_type => "integer", is_nullable => 1 },
  "delivered",
  { data_type => "integer", is_nullable => 1 },
  "main_stock",
  { data_type => "integer", is_nullable => 1 },
  "sample_stock",
  { data_type => "integer", is_nullable => 1 },
  "sample_request",
  { data_type => "integer", is_nullable => 1 },
  "reserved",
  { data_type => "integer", is_nullable => 1 },
  "pre_pick",
  { data_type => "integer", is_nullable => 1 },
  "cancel_pending",
  { data_type => "integer", is_nullable => 0 },
  "last_updated",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "arrival_date",
  { data_type => "date", is_nullable => 1 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("product_id", "channel_id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "product",
  "XTracker::Schema::Result::Public::Product",
  { id => "product_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "product_channel",
  "XTracker::Schema::Result::Public::ProductChannel",
  { channel_id => "channel_id", product_id => "product_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rqzh+sHUslzpyvYYghpPZw

__PACKAGE__->belongs_to(
    'price_purchase' => 'XTracker::Schema::Result::Public::PricePurchase',
    { 'foreign.product_id' => 'self.product_id' }
);

1;
