use utf8;
package XTracker::Schema::Result::Public::LinkBulkReimbursementOrder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_bulk_reimbursement__orders");
__PACKAGE__->add_columns(
  "bulk_reimbursement_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "order_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "completed",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("bulk_reimbursement_id", "order_id");
__PACKAGE__->belongs_to(
  "bulk_reimbursement",
  "XTracker::Schema::Result::Public::BulkReimbursement",
  { id => "bulk_reimbursement_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "order",
  "XTracker::Schema::Result::Public::Orders",
  { id => "order_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xnBFhbN5mHze+cr8m4ze5g

=head1 NAME

XTracker::Schema::Result::Public::LinkBulkReimbursementOrder

=cut

1;
