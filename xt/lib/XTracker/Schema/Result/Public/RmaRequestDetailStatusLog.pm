use utf8;
package XTracker::Schema::Result::Public::RmaRequestDetailStatusLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.rma_request_detail_status_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "rma_request_detail_status_log_id_seq",
  },
  "rma_request_detail_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "rma_request_detail_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date_time",
  {
    data_type     => "timestamp",
    default_value => \"('now'::text)::timestamp without time zone",
    is_nullable   => 0,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "rma_request_detail",
  "XTracker::Schema::Result::Public::RmaRequestDetail",
  { id => "rma_request_detail_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wDugHWAo2jF0uB5Ar22pdg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
