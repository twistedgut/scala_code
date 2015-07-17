use utf8;
package XTracker::Schema::Result::Public::LinkShipmentItemPromotion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_shipment_item__promotion");
__PACKAGE__->add_columns(
  "shipment_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "promotion",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "unit_price",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "tax",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "duty",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("shipment_item_id");
__PACKAGE__->belongs_to(
  "shipment_item",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { id => "shipment_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:m4ZMDNNED9B6LuW7cAAPNA

use XTracker::SchemaHelper qw(:records);

1;
