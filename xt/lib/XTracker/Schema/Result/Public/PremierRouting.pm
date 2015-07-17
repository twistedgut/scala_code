use utf8;
package XTracker::Schema::Result::Public::PremierRouting;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.premier_routing");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 0 },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 1 },
  "earliest_delivery_daytime",
  { data_type => "time", is_nullable => 0 },
  "latest_delivery_daytime",
  { data_type => "time", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "shipments",
  "XTracker::Schema::Result::Public::Shipment",
  { "foreign.premier_routing_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipping_charges",
  "XTracker::Schema::Result::Public::ShippingCharge",
  { "foreign.premier_routing_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9pW9Shjg3BtU+U33VE/3LA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
