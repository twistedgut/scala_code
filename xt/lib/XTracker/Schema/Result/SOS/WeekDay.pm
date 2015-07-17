use utf8;
package XTracker::Schema::Result::SOS::WeekDay;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("sos.week_day");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sos.week_day_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "next_day_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("week_day_next_day_id_key", ["next_day_id"]);
__PACKAGE__->belongs_to(
  "next_day",
  "XTracker::Schema::Result::SOS::WeekDay",
  { id => "next_day_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "truck_departures",
  "XTracker::Schema::Result::SOS::TruckDeparture",
  { "foreign.week_day_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "week_day",
  "XTracker::Schema::Result::SOS::WeekDay",
  { "foreign.next_day_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tpw/cztdkEMk0XGPiAGKcw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
