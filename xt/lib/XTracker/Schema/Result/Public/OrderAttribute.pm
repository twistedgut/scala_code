use utf8;
package XTracker::Schema::Result::Public::OrderAttribute;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.order_attribute");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "order_attribute_id_seq",
  },
  "orders_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "source_app_name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "source_app_version",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("order_attribute_orders_id_key", ["orders_id"]);
__PACKAGE__->belongs_to(
  "order",
  "XTracker::Schema::Result::Public::Orders",
  { id => "orders_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uMvePu1mI9+ULACKLI6PkQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
