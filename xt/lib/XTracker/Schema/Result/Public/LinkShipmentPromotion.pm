use utf8;
package XTracker::Schema::Result::Public::LinkShipmentPromotion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_shipment__promotion");
__PACKAGE__->add_columns(
  "shipment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "promotion",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "value",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("shipment_id");
__PACKAGE__->belongs_to(
  "shipment",
  "XTracker::Schema::Result::Public::Shipment",
  { id => "shipment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jKQX4z7Se7dGUXdxdox/9Q


# You can replace this text with custom content, and it will be preserved on regeneration
1;
