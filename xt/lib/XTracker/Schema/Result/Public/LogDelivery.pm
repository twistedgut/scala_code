use utf8;
package XTracker::Schema::Result::Public::LogDelivery;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.log_delivery");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "log_delivery_id_seq",
  },
  "delivery_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "delivery_action_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "quantity",
  { data_type => "integer", is_nullable => 0 },
  "notes",
  { data_type => "text", is_nullable => 1 },
  "date",
  {
    data_type     => "timestamp",
    default_value => \"('now'::text)::timestamp(6) with time zone",
    is_nullable   => 0,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "delivery",
  "XTracker::Schema::Result::Public::Delivery",
  { id => "delivery_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "delivery_action",
  "XTracker::Schema::Result::Public::DeliveryAction",
  { id => "delivery_action_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::Public::StockProcessType",
  { id => "type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:OGtY+JW+z1UqeK8TEeSa6g

__PACKAGE__->belongs_to(
    'stock_process_type' => 'Public::StockProcessType',
    { 'foreign.id' => 'self.type_id' },
);

1;
