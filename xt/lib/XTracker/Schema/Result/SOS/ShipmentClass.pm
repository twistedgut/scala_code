use utf8;
package XTracker::Schema::Result::SOS::ShipmentClass;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("sos.shipment_class");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sos.shipment_class_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "api_code",
  { data_type => "text", is_nullable => 0 },
  "use_truck_departure_times_for_sla",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "does_ignore_other_processing_times",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("shipment_class_api_code_key", ["api_code"]);
__PACKAGE__->might_have(
  "processing_time",
  "XTracker::Schema::Result::SOS::ProcessingTime",
  { "foreign.class_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "truck_departure__shipment_classes",
  "XTracker::Schema::Result::SOS::TruckDepartureShipmentClass",
  { "foreign.shipment_class_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "truck_departure_exception__shipment_classes",
  "XTracker::Schema::Result::SOS::TruckDepartureExceptionShipmentClass",
  { "foreign.shipment_class_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "wms_priority",
  "XTracker::Schema::Result::SOS::WmsPriority",
  { "foreign.shipment_class_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:USGWL1trYeUcESndPz34hg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
