use utf8;
package XTracker::Schema::Result::Public::CsmExclusionCalendar;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.csm_exclusion_calendar");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "csm_exclusion_calendar_id_seq",
  },
  "csm_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "start_time",
  { data_type => "time", is_nullable => 1 },
  "end_time",
  { data_type => "time", is_nullable => 1 },
  "start_date",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "end_date",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "day_of_week",
  { data_type => "varchar", is_nullable => 1, size => 13 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "csm_exclusion_calendar_csm_id_start_time_end_time_start_dat_key",
  [
    "csm_id",
    "start_time",
    "end_time",
    "start_date",
    "end_date",
    "day_of_week",
  ],
);
__PACKAGE__->belongs_to(
  "csm",
  "XTracker::Schema::Result::Public::CorrespondenceSubjectMethod",
  { id => "csm_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:VSrnaiPV+ltSImk6AeB58A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
