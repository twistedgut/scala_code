use utf8;
package XTracker::Schema::Result::Public::LogShipmentRtcbState;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.log_shipment_rtcb_state");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "log_shipment_rtcb_state_id_seq",
  },
  "shipment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "new_state",
  { data_type => "boolean", is_nullable => 0 },
  "date_changed",
  {
    data_type     => "timestamp with time zone",
    default_value => \"('now'::text)::timestamp(6) with time zone",
    is_nullable   => 0,
  },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "reason_for_change",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment",
  "XTracker::Schema::Result::Public::Shipment",
  { id => "shipment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BIAumBxmB0OfRldf22ifvg


# You can replace this text with custom content, and it will be preserved on regeneration

1;
