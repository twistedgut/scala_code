use utf8;
package XTracker::Schema::Result::Public::AddressChangeLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.address_change_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "address_change_log_id_seq",
  },
  "orders_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "address_type",
  { data_type => "integer", is_nullable => 0 },
  "change_from",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "change_to",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date",
  { data_type => "timestamp", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "change_from",
  "XTracker::Schema::Result::Public::OrderAddress",
  { id => "change_from" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "change_to",
  "XTracker::Schema::Result::Public::OrderAddress",
  { id => "change_to" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "order",
  "XTracker::Schema::Result::Public::Orders",
  { id => "orders_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:owyv3rBnASCgn3qfMPNzQQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
