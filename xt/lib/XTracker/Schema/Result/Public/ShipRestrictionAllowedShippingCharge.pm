use utf8;
package XTracker::Schema::Result::Public::ShipRestrictionAllowedShippingCharge;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.ship_restriction_allowed_shipping_charge");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "ship_restriction_allowed_shipping_charge_id_seq",
  },
  "ship_restriction_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipping_charge_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "ship_restriction_allowed_ship_ship_restriction_id_shipping__key",
  ["ship_restriction_id", "shipping_charge_id"],
);
__PACKAGE__->belongs_to(
  "ship_restriction",
  "XTracker::Schema::Result::Public::ShipRestriction",
  { id => "ship_restriction_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipping_charge",
  "XTracker::Schema::Result::Public::ShippingCharge",
  { id => "shipping_charge_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SQUs9B3MvzX+Jorybs5B8A


1;
