use utf8;
package XTracker::Schema::Result::SOS::TruckDeparture;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime", "InflateColumn::Time");
__PACKAGE__->table("sos.truck_departure");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sos.truck_departure_id_seq",
  },
  "begin_date",
  { data_type => "date", is_nullable => 0 },
  "end_date",
  { data_type => "date", is_nullable => 1 },
  "carrier_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "week_day_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "departure_time",
  { data_type => "time", is_nullable => 0 },
  "created_datetime",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "archived_datetime",
  { data_type => "timestamp with time zone", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "carrier",
  "XTracker::Schema::Result::SOS::Carrier",
  { id => "carrier_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "truck_departure__shipment_classes",
  "XTracker::Schema::Result::SOS::TruckDepartureShipmentClass",
  { "foreign.truck_departure_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "week_day",
  "XTracker::Schema::Result::SOS::WeekDay",
  { id => "week_day_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:pTFah8HpPz6MENH9zT1hVg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
