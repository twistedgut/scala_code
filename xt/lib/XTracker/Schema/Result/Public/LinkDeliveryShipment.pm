use utf8;
package XTracker::Schema::Result::Public::LinkDeliveryShipment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_delivery__shipment");
__PACKAGE__->add_columns(
  "delivery_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("delivery_id", "shipment_id");
__PACKAGE__->belongs_to(
  "delivery",
  "XTracker::Schema::Result::Public::Delivery",
  { id => "delivery_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment",
  "XTracker::Schema::Result::Public::Shipment",
  { id => "shipment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3BDJjo9koZT2AVR6u97CJQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
