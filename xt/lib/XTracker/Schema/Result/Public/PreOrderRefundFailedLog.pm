use utf8;
package XTracker::Schema::Result::Public::PreOrderRefundFailedLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.pre_order_refund_failed_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "pre_order_refund_failed_log_id_seq",
  },
  "pre_order_refund_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "preauth_ref_used",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "failure_message",
  { data_type => "text", is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
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
  "pre_order_refund",
  "XTracker::Schema::Result::Public::PreOrderRefund",
  { id => "pre_order_refund_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RKEiSpYkAJEXztnnQP5C4g


# You can replace this text with custom code or comments, and it will be preserved on regeneration


1;
