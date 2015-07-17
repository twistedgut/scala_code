use utf8;
package XTracker::Schema::Result::Public::BulkReimbursementStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.bulk_reimbursement_status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "bulk_reimbursement_status_id_seq",
  },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("bulk_reimbursement_status_status_unique", ["status"]);
__PACKAGE__->has_many(
  "bulk_reimbursements",
  "XTracker::Schema::Result::Public::BulkReimbursement",
  { "foreign.bulk_reimbursement_status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:o63hFgjSo3GqIidl/GmSdA

=head1 NAME

XTracker::Schema::Result::Public::BulkReimbursementStatus

=cut

1;
