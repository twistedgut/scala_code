use utf8;
package XTracker::Schema::Result::SOS::Carrier;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("sos.carrier");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sos.carrier_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "code",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("carrier_code_key", ["code"]);
__PACKAGE__->add_unique_constraint("carrier_name_key", ["name"]);
__PACKAGE__->has_many(
  "truck_departure_exceptions",
  "XTracker::Schema::Result::SOS::TruckDepartureException",
  { "foreign.carrier_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "truck_departures",
  "XTracker::Schema::Result::SOS::TruckDeparture",
  { "foreign.carrier_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CvtwzM5XlVsfTImbqrG+mA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
