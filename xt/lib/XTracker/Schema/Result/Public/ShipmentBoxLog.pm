use utf8;
package XTracker::Schema::Result::Public::ShipmentBoxLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipment_box_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipment_box_log_id_seq",
  },
  "shipment_box_id",
  { data_type => "text", is_nullable => 0 },
  "skus",
  { data_type => "text[]", is_nullable => 0 },
  "action",
  { data_type => "text", is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "timestamp",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gCGsacSjlZiCuDyqp8JYdg

__PACKAGE__->belongs_to(
  "shipment_box",
  "XTracker::Schema::Result::Public::ShipmentBox",
  { id => "shipment_box_id" },
  {},
);

1;
