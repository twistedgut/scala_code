use utf8;
package XTracker::Schema::Result::Public::RTVQuantity;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.rtv_quantity");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "rtv_quantity_id_seq",
  },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "location_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "quantity",
  { data_type => "integer", is_nullable => 0 },
  "delivery_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "fault_type_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "fault_description",
  { data_type => "varchar", is_nullable => 1, size => 2000 },
  "origin",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "date_created",
  {
    data_type     => "timestamp",
    default_value => \"('now'::text)::timestamp without time zone",
    is_nullable   => 0,
  },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "delivery_item",
  "XTracker::Schema::Result::Public::DeliveryItem",
  { id => "delivery_item_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "item_fault_type",
  "XTracker::Schema::Result::Public::ItemFaultType",
  { id => "fault_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "location",
  "XTracker::Schema::Result::Public::Location",
  { id => "location_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Flow::Status",
  { id => "status_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wHAHKs4UaDp/52DWLyZBRQ

__PACKAGE__->has_many(
    rtv_inspection_pick_request_details => 'XTracker::Schema::Result::Public::RTVInspectionPickRequestDetail',
    { 'foreign.rtv_quantity_id' => 'self.id' },
);

__PACKAGE__->might_have(
    'rma_request_detail' => 'Public::RmaRequestDetail',
    { 'foreign.rtv_quantity_id' => 'self.id' },
);

1;
