use utf8;
package XTracker::Schema::Result::Public::LinkOrdersPreOrder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_orders__pre_order");
__PACKAGE__->add_columns(
  "orders_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pre_order_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->add_unique_constraint(
  "link_orders__pre_order__unique_ref",
  ["orders_id", "pre_order_id"],
);
__PACKAGE__->belongs_to(
  "order",
  "XTracker::Schema::Result::Public::Orders",
  { id => "orders_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "pre_order",
  "XTracker::Schema::Result::Public::PreOrder",
  { id => "pre_order_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GpHeXG5xvu3LqqSCQ3jm7g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
# This relation should be replaced with the automatically generated one...
# ALTHOUGH the other one uses a reserved name (order) so pg will error unless
# you turn on quoting. See
# XTracker::Schema::ResultSet::Public::ShipmentItemStatusLog::filter_by_customer_channel
# for use case
__PACKAGE__->belongs_to(
  "orders",
    "XTracker::Schema::Result::Public::Orders",
      { id => "orders_id" },
      );

1;
