use utf8;
package XTracker::Schema::Result::Public::RmaRequest;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.rma_request");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "rma_request_id_seq",
  },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date_request",
  {
    data_type     => "timestamp",
    default_value => \"('now'::text)::timestamp without time zone",
    is_nullable   => 0,
  },
  "date_complete",
  { data_type => "timestamp", is_nullable => 1 },
  "date_followup",
  {
    data_type     => "timestamp",
    default_value => \"(('now'::text)::timestamp without time zone + '10 days'::interval)",
    is_nullable   => 0,
  },
  "rma_number",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "comments",
  { data_type => "varchar", is_nullable => 1, size => 1000 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "rma_request_details",
  "XTracker::Schema::Result::Public::RmaRequestDetail",
  { "foreign.rma_request_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7EC1XXaTwZQjHxD9yiDSjw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
