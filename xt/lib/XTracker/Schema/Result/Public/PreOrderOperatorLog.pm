use utf8;
package XTracker::Schema::Result::Public::PreOrderOperatorLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.pre_order_operator_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "pre_order_operator_log_id_seq",
  },
  "pre_order_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pre_order_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "from_operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "to_operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "from_operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "from_operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "pre_order",
  "XTracker::Schema::Result::Public::PreOrder",
  { id => "pre_order_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "pre_order_status",
  "XTracker::Schema::Result::Public::PreOrderStatus",
  { id => "pre_order_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "to_operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "to_operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QggRaTw1BUKYFr/xzvKZnw


1;
