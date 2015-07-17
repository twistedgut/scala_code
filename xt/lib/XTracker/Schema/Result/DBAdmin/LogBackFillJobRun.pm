use utf8;
package XTracker::Schema::Result::DBAdmin::LogBackFillJobRun;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("dbadmin.log_back_fill_job_run");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dbadmin.log_back_fill_job_run_id_seq",
  },
  "back_fill_job_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "number_of_rows_updated",
  { data_type => "integer", is_nullable => 0 },
  "error_was_thrown",
  { data_type => "boolean", is_nullable => 0 },
  "start_time",
  { data_type => "timestamp with time zone", is_nullable => 0 },
  "finish_time",
  { data_type => "timestamp with time zone", is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "back_fill_job",
  "XTracker::Schema::Result::DBAdmin::BackFillJob",
  { id => "back_fill_job_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8CYchfNA3K3BucKtxdzDrg


__PACKAGE__->belongs_to(
    'operator'  => 'XTracker::Schema::Result::Public::Operator',
    { 'foreign.id' => 'self.operator_id' },
);


1;
