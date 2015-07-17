use utf8;
package XTracker::Schema::Result::SOS::TruckDepartureExceptionShipmentClass;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("sos.truck_departure_exception__shipment_class");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sos.truck_departure_exception__shipment_class_id_seq",
  },
  "truck_departure_exception_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipment_class_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "shipment_class",
  "XTracker::Schema::Result::SOS::ShipmentClass",
  { id => "shipment_class_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "truck_departure_exception",
  "XTracker::Schema::Result::SOS::TruckDepartureException",
  { id => "truck_departure_exception_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zjoWUMdtSA9szRa9PHujiA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
