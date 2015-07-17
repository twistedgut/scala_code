use utf8;
package XTracker::Schema::Result::Public::DispatchLaneOffset;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.dispatch_lane_offset");
__PACKAGE__->add_columns(
  "shipment_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "lane_offset",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("shipment_type_id");
__PACKAGE__->belongs_to(
  "shipment_type",
  "XTracker::Schema::Result::Public::ShipmentType",
  { id => "shipment_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4Jy1N3CEGU4wvLx/2ms+lw

__PACKAGE__->belongs_to(
 "shipment_type",
 "XTracker::Schema::Result::Public::ShipmentType",
 { id => "shipment_type_id" },
 {},
);

1;
