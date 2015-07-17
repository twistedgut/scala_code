use utf8;
package XTracker::Schema::Result::Public::PreOrderItemStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.pre_order_item_status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "pre_order_item_status_id_seq",
  },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 50 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("pre_order_item_status_status_key", ["status"]);
__PACKAGE__->has_many(
  "pre_order_item_status_logs",
  "XTracker::Schema::Result::Public::PreOrderItemStatusLog",
  { "foreign.pre_order_item_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_items",
  "XTracker::Schema::Result::Public::PreOrderItem",
  { "foreign.pre_order_item_status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vUn4/GB7DLcA9s6PW9Atgw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;