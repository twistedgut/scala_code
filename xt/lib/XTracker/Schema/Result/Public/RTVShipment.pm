use utf8;
package XTracker::Schema::Result::Public::RTVShipment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.rtv_shipment");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "rtv_shipment_id_seq",
  },
  "designer_rtv_carrier_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "designer_rtv_address_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date_time",
  {
    data_type     => "timestamp",
    default_value => \"('now'::text)::timestamp without time zone",
    is_nullable   => 0,
  },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "airway_bill",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "rtv_shipment_details",
  "XTracker::Schema::Result::Public::RTVShipmentDetail",
  { "foreign.rtv_shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rtv_shipment_status_logs",
  "XTracker::Schema::Result::Public::RTVShipmentStatusLog",
  { "foreign.rtv_shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::RTVShipmentStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mHTB9VF2JUD2x7zAMVfHSw

# This should be a has_many relation, but it breaks
# Public::RTVShipment::packing_summary as DBIx can't handle two has_many
# relations in the same query (the other one being rtv_shipment_details)
__PACKAGE__->belongs_to(
    'rtv_shipment_status_log' => 'Public::RTVShipmentStatusLog',
    { 'foreign.rtv_shipment_id' => 'self.id' },
    { join_type => 'left'},
);

1;
