use utf8;
package XTracker::Schema::Result::Public::CustomerCreditLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.customer_credit_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "customer_credit_log_id_seq",
  },
  "customer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "change",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "balance",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "action",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "date",
  { data_type => "timestamp", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "customer",
  "XTracker::Schema::Result::Public::Customer",
  { id => "customer_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:z74Qy+k4cwkMbB5p4Lhy7w

__PACKAGE__->has_one(
  "customer_credit",
  "XTracker::Schema::Result::Public::CustomerCredit",
  { "foreign.customer_id" => "self.customer_id" },
  {},
);

1;
