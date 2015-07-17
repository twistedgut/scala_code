use utf8;
package XTracker::Schema::Result::Public::CardPayment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.card_payment");
__PACKAGE__->add_columns(
  "orders_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "number",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "expiry_date",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "auth_code",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "fraud_score",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "transaction_reference",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "value",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "fulfilled",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "fulfill_status",
  { data_type => "integer", is_nullable => 1 },
  "fulfill_reason",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "fulfill_date",
  { data_type => "timestamp", is_nullable => 1 },
  "valid",
  { data_type => "boolean", default_value => \"true", is_nullable => 1 },
  "threedsecure_response",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("orders_id");
__PACKAGE__->belongs_to(
  "order",
  "XTracker::Schema::Result::Public::Orders",
  { id => "orders_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zXDVBKcaEpdmOtP4v6L0IA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
