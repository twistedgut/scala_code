use utf8;
package XTracker::Schema::Result::Public::LinkRoutingScheduleReturn;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_routing_schedule__return");
__PACKAGE__->add_columns(
  "routing_schedule_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "return_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("routing_schedule_id", "return_id");
__PACKAGE__->add_unique_constraint(
  "link_routing_schedule__return_routing_schedule_id_key",
  ["routing_schedule_id"],
);
__PACKAGE__->belongs_to(
  "return",
  "XTracker::Schema::Result::Public::Return",
  { id => "return_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "routing_schedule",
  "XTracker::Schema::Result::Public::RoutingSchedule",
  { id => "routing_schedule_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sJIm3e/7+JF4xzi8p20JEQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
