use utf8;
package XTracker::Schema::Result::Public::ShipmentItemStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipment_item_status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipment_item_status_id_seq",
  },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "fulfilment_overview_stage_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "fulfilment_overview_stage",
  "XTracker::Schema::Result::Public::FulfilmentOverviewStage",
  { id => "fulfilment_overview_stage_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "shipment_item_status_logs",
  "XTracker::Schema::Result::Public::ShipmentItemStatusLog",
  { "foreign.shipment_item_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_items",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { "foreign.shipment_item_status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sJLA8jVRhDYG2jDajo8pDg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
