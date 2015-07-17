use utf8;
package XTracker::Schema::Result::Public::RecommendedProduct;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.recommended_product");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "recommended_product_id_seq",
  },
  "product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "recommended_product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type_id",
  {
    data_type      => "integer",
    default_value  => 1,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "sort_order",
  { data_type => "integer", is_nullable => 1 },
  "slot",
  { data_type => "integer", is_nullable => 1 },
  "approved",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "auto_set",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "product",
  "XTracker::Schema::Result::Public::Product",
  { id => "product_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "recommended_product",
  "XTracker::Schema::Result::Public::Product",
  { id => "recommended_product_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::Public::RecommendedProductType",
  { id => "type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1XdsAyxczG6TYbaafL4Vgw


__PACKAGE__->belongs_to(
    product_channel => 'XTracker::Schema::Result::Public::ProductChannel',
    { 'foreign.product_id' => 'self.product_id',
      'foreign.channel_id' => 'self.channel_id', },
);
__PACKAGE__->belongs_to(
    recommended_product_channel => 'XTracker::Schema::Result::Public::ProductChannel',
    { 'foreign.product_id' => 'self.recommended_product_id',
      'foreign.channel_id' => 'self.channel_id', },
);

1;
