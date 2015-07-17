use utf8;
package XTracker::Schema::Result::Orders::LogReplacedPaymentValidChange;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("orders.log_replaced_payment_valid_change");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "orders.log_replaced_payment_valid_change_id_seq",
  },
  "replaced_payment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date_changed",
  { data_type => "timestamp with time zone", is_nullable => 0 },
  "new_state",
  { data_type => "boolean", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "replaced_payment",
  "XTracker::Schema::Result::Orders::ReplacedPayment",
  { id => "replaced_payment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4TJvHQuyfwzGaEXJA2M0qg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
