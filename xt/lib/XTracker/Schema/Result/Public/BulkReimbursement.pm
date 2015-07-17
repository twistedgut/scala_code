use utf8;
package XTracker::Schema::Result::Public::BulkReimbursement;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.bulk_reimbursement");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "bulk_reimbursement_id_seq",
  },
  "created_timestamp",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "bulk_reimbursement_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "credit_amount",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "reason",
  { data_type => "varchar", is_nullable => 0, size => 250 },
  "send_email",
  { data_type => "boolean", is_nullable => 0 },
  "email_subject",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "email_message",
  { data_type => "text", is_nullable => 1 },
  "renumeration_reason_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "bulk_reimbursement_status",
  "XTracker::Schema::Result::Public::BulkReimbursementStatus",
  { id => "bulk_reimbursement_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "link_bulk_reimbursement__orders",
  "XTracker::Schema::Result::Public::LinkBulkReimbursementOrder",
  { "foreign.bulk_reimbursement_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "renumeration_reason",
  "XTracker::Schema::Result::Public::RenumerationReason",
  { id => "renumeration_reason_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:c6Hr3IoWwxuNkJc6uCmejQ

=head1 NAME

XTracker::Schema::Result::Public::BulkReimbursement

=cut

1;
