use utf8;
package XTracker::Schema::Result::Public::PriceDefault;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.price_default");
__PACKAGE__->add_columns(
  "product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "price",
  {
    data_type => "numeric",
    default_value => 0,
    is_nullable => 0,
    size => [10, 2],
  },
  "currency_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "complete",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "complete_by_operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "operator_id",
  { data_type => "integer", is_nullable => 1 },
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "price_default_id_seq",
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("price_default_product_id_key", ["product_id"]);
__PACKAGE__->belongs_to(
  "complete_by_operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "complete_by_operator_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "currency",
  "XTracker::Schema::Result::Public::Currency",
  { id => "currency_id" },
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


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AKPR/vUsREw3mOc8phkFRw

__PACKAGE__->belongs_to(
    'operator'  => 'Public::Operator',
    { 'foreign.id' => 'self.operator_id' }
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
