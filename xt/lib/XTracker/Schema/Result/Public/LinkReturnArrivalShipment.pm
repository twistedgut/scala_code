use utf8;
package XTracker::Schema::Result::Public::LinkReturnArrivalShipment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_return_arrival__shipment");
__PACKAGE__->add_columns(
  "return_arrival_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("return_arrival_id", "shipment_id");
__PACKAGE__->belongs_to(
  "return_arrival",
  "XTracker::Schema::Result::Public::ReturnArrival",
  { id => "return_arrival_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment",
  "XTracker::Schema::Result::Public::Shipment",
  { id => "shipment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:JhV/gCodogqJx85tgk9Yug

__PACKAGE__->set_primary_key("shipment_id", "return_arrival_id");

1;
