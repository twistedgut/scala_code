use utf8;
package XTracker::Schema::Result::Public::LinkDeliveryReturn;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_delivery__return");
__PACKAGE__->add_columns(
  "delivery_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "return_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("delivery_id");
__PACKAGE__->belongs_to(
  "delivery",
  "XTracker::Schema::Result::Public::Delivery",
  { id => "delivery_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "return",
  "XTracker::Schema::Result::Public::Return",
  { id => "return_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:92apw1235AGSTidFym5PVg


# You can replace this text with custom content, and it will be preserved on regeneration
1;