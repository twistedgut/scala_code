use utf8;
package XTracker::Schema::Result::Public::RoutingExport;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.routing_export");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "routing_export_id_seq",
  },
  "filename",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "cut_off",
  { data_type => "timestamp", is_nullable => 0 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
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
  "link_routing_export__returns",
  "XTracker::Schema::Result::Public::LinkRoutingExportReturn",
  { "foreign.routing_export_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_routing_export__shipments",
  "XTracker::Schema::Result::Public::LinkRoutingExportShipment",
  { "foreign.routing_export_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "routing_export_status_logs",
  "XTracker::Schema::Result::Public::RoutingExportStatusLog",
  { "foreign.routing_export_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::RoutingExportStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->many_to_many("returns", "link_routing_export__returns", "return");
__PACKAGE__->many_to_many("shipments", "link_routing_export__shipments", "shipment");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1/0x1LpdVC/IOXwzNnaZYQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
