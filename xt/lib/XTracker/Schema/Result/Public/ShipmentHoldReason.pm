use utf8;
package XTracker::Schema::Result::Public::ShipmentHoldReason;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipment_hold_reason");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipment_hold_reason_id_seq",
  },
  "reason",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "manually_releasable",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "information",
  { data_type => "text", is_nullable => 1 },
  "allow_new_sla_on_release",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("shipment_hold_reason_reason_key", ["reason"]);
__PACKAGE__->has_many(
  "shipment_hold_logs",
  "XTracker::Schema::Result::Public::ShipmentHoldLog",
  { "foreign.shipment_hold_reason_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_holds",
  "XTracker::Schema::Result::Public::ShipmentHold",
  { "foreign.shipment_hold_reason_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FZHsqH7Hwht+mYjDExpVYQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
