use utf8;
package XTracker::Schema::Result::Public::LinkShipmentItemReservationByPid;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_shipment_item__reservation_by_pid");
__PACKAGE__->add_columns(
  "shipment_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "reservation_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->add_unique_constraint(
  "link_shipment_item__reservation_by_pid__unique_ref",
  ["shipment_item_id", "reservation_id"],
);
__PACKAGE__->belongs_to(
  "reservation",
  "XTracker::Schema::Result::Public::Reservation",
  { id => "reservation_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment_item",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { id => "shipment_item_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:A+V1aebcU50V+jXTBcYTaQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
