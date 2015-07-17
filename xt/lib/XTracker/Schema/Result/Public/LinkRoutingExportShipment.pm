use utf8;
package XTracker::Schema::Result::Public::LinkRoutingExportShipment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_routing_export__shipment");
__PACKAGE__->add_columns(
  "routing_export_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("routing_export_id", "shipment_id");
__PACKAGE__->belongs_to(
  "routing_export",
  "XTracker::Schema::Result::Public::RoutingExport",
  { id => "routing_export_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment",
  "XTracker::Schema::Result::Public::Shipment",
  { id => "shipment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AY/ihxdfgZeoWlSXE2IH5g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
