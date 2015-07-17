use utf8;
package XTracker::Schema::Result::Public::StockOrderItemType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.stock_order_item_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "stock_order_item_type_id_seq",
  },
  "type",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "stock_order_items",
  "XTracker::Schema::Result::Public::StockOrderItem",
  { "foreign.type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WdpUT30DIxP8g33kWfXHJg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
