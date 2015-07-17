use utf8;
package XTracker::Schema::Result::Public::PrlPickTriggerOrder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.prl_pick_trigger_order");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "triggers_picks_in_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "picks_triggered_by_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "trigger_order",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "picks_triggered_by",
  "XTracker::Schema::Result::Public::Prl",
  { id => "picks_triggered_by_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "triggers_picks_in",
  "XTracker::Schema::Result::Public::Prl",
  { id => "triggers_picks_in_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WLdbCUPwMPRRz+3QSjxV/w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
