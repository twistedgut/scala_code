use utf8;
package XTracker::Schema::Result::Public::LinkShipmentTypeDispatchLane;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_shipment_type__dispatch_lane");
__PACKAGE__->add_columns(
  "shipment_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "dispatch_lane_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("shipment_type_id", "dispatch_lane_id");
__PACKAGE__->belongs_to(
  "dispatch_lane",
  "XTracker::Schema::Result::Public::DispatchLane",
  { id => "dispatch_lane_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment_type",
  "XTracker::Schema::Result::Public::ShipmentType",
  { id => "shipment_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WeH1aXFbHNT9nNOLJkP4Fw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
