use utf8;
package XTracker::Schema::Result::Public::ShipmentItemReturnableState;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipment_item_returnable_state");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipment_item_returnable_state_id_seq",
  },
  "state",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "pws_key",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "returnable_on_pws",
  { data_type => "boolean", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("shipment_item_returnable_state_pws_key_key", ["pws_key"]);
__PACKAGE__->add_unique_constraint("shipment_item_returnable_state_state_key", ["state"]);
__PACKAGE__->has_many(
  "shipment_items",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { "foreign.returnable_state_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QWVjeASKFHpU683f7qopjQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
