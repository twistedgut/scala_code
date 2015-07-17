use utf8;
package XTracker::Schema::Result::Orders::ThirdPartyPaymentMethodStatusMap;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("orders.third_party_payment_method_status_map");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "orders.third_party_payment_method_status_map_id_seq",
  },
  "payment_method_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "third_party_status",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "internal_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "third_party_payment_method_st_payment_method_id_third_party_key",
  [
    "payment_method_id",
    "third_party_status",
    "internal_status_id",
  ],
);
__PACKAGE__->belongs_to(
  "internal_status",
  "XTracker::Schema::Result::Orders::InternalThirdPartyStatus",
  { id => "internal_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "payment_method",
  "XTracker::Schema::Result::Orders::PaymentMethod",
  { id => "payment_method_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fV+YKjCmSQLr4dqM3uLaeQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
