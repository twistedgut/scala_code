use utf8;
package XTracker::Schema::Result::Product::PWSSortOrder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("product.pws_sort_order");
__PACKAGE__->add_columns(
  "product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pws_sort_destination_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "score",
  { data_type => "numeric", is_nullable => 0 },
  "score_offset",
  { data_type => "numeric", is_nullable => 0 },
  "sort_order",
  { data_type => "integer", is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->add_unique_constraint(
  "pws_sort_order_pkey",
  ["product_id", "pws_sort_destination_id", "channel_id"],
);
__PACKAGE__->add_unique_constraint(
  "uix_pws_sort_order__sort_order",
  ["pws_sort_destination_id", "sort_order", "channel_id"],
);
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


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TisUg4Oo75U5QtWCMsSd4g

__PACKAGE__->set_primary_key('product_id');

1;
