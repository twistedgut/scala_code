use utf8;
package XTracker::Schema::Result::Public::LinkOrderShipment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_orders__shipment");
__PACKAGE__->add_columns(
  "orders_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("orders_id", "shipment_id");
__PACKAGE__->belongs_to(
  "orders",
  "XTracker::Schema::Result::Public::Orders",
  { id => "orders_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment",
  "XTracker::Schema::Result::Public::Shipment",
  { id => "shipment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+aDbxzkW5N6VjGwXU/KWpw

# back-compat relationship, only for accessors. can't work for joins,
# since "order" is a reserved word, and we don't quote identifiers
__PACKAGE__->belongs_to(
  "order",
  "XTracker::Schema::Result::Public::Orders",
  { id => "orders_id" },
);

1;
