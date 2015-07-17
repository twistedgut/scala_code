use utf8;
package XTracker::Schema::Result::Public::ShipmentItemOnSaleFlag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipment_item_on_sale_flag");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipment_item_on_sale_flag_id_seq",
  },
  "pws_key",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "flag",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "on_sale",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "shipment_items",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { "foreign.sale_flag_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dTX//6W/SVcKgFLB9g0g7A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
