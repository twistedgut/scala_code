use utf8;
package XTracker::Schema::Result::Product::AttributeValue;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("product.attribute_value");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "product.attribute_value_id_seq",
  },
  "product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "attribute_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "deleted",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "sort_order",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "attribute_value_product_id_key",
  ["product_id", "attribute_id"],
);
__PACKAGE__->belongs_to(
  "attribute",
  "XTracker::Schema::Result::Product::Attribute",
  { id => "attribute_id" },
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
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BBbkIKGJaRToqDqIgkj0GQ

__PACKAGE__->belongs_to(
    'product_channel' => 'XTracker::Schema::Result::Public::ProductChannel',
    { 'foreign.product_id' => 'self.product_id' }
);

1;
