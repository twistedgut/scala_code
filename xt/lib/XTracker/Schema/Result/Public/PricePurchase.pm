use utf8;
package XTracker::Schema::Result::Public::PricePurchase;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.price_purchase");
__PACKAGE__->add_columns(
  "product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "wholesale_price",
  {
    data_type => "numeric",
    default_value => 0,
    is_nullable => 0,
    size => [10, 3],
  },
  "wholesale_currency_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "original_wholesale",
  { data_type => "numeric", is_nullable => 1, size => [10, 3] },
  "uplift_cost",
  { data_type => "numeric", is_nullable => 1, size => [10, 3] },
  "uk_landed_cost",
  { data_type => "numeric", is_nullable => 1, size => [10, 3] },
  "uplift",
  {
    data_type => "numeric",
    default_value => 0,
    is_nullable => 0,
    size => [10, 2],
  },
  "trade_discount",
  {
    data_type => "numeric",
    default_value => 0,
    is_nullable => 0,
    size => [10, 2],
  },
);
__PACKAGE__->set_primary_key("product_id");
__PACKAGE__->belongs_to(
  "product",
  "XTracker::Schema::Result::Public::Product",
  { id => "product_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "wholesale_currency",
  "XTracker::Schema::Result::Public::Currency",
  { id => "wholesale_currency_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9TKXjwzMM1WG//UXwZjtpA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
