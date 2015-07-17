use utf8;
package XTracker::Schema::Result::DBAdmin::BackFillJobStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("dbadmin.back_fill_job_status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dbadmin.back_fill_job_status_id_seq",
  },
  "status",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "back_fill_jobs",
  "XTracker::Schema::Result::DBAdmin::BackFillJob",
  { "foreign.back_fill_job_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_back_fill_job_statuses",
  "XTracker::Schema::Result::DBAdmin::LogBackFillJobStatus",
  { "foreign.back_fill_job_status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AQ7g7RYEDcG001YE+T7gSw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
