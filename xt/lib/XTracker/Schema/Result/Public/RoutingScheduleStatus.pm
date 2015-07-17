use utf8;
package XTracker::Schema::Result::Public::RoutingScheduleStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.routing_schedule_status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "routing_schedule_status_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "rank",
  { data_type => "smallint", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("routing_schedule_status_name_key", ["name"]);
__PACKAGE__->has_many(
  "routing_schedules",
  "XTracker::Schema::Result::Public::RoutingSchedule",
  { "foreign.routing_schedule_status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4YdEsWZlhYZl/J92uz/C7w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;