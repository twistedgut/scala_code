use utf8;
package XTracker::Schema::Result::Public::UpsServiceAvailability;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.ups_service_availability");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "ups_service_availability_id_seq",
  },
  "ups_service_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipping_class_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipping_direction_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipping_charge_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "rank",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "ups_service_availability_ups_service_id_shipping_class_id_s_key",
  [
    "ups_service_id",
    "shipping_class_id",
    "shipping_direction_id",
    "shipping_charge_id",
  ],
);
__PACKAGE__->belongs_to(
  "shipping_charge",
  "XTracker::Schema::Result::Public::ShippingCharge",
  { id => "shipping_charge_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "shipping_class",
  "XTracker::Schema::Result::Public::ShippingClass",
  { id => "shipping_class_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipping_direction",
  "XTracker::Schema::Result::Public::ShippingDirection",
  { id => "shipping_direction_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "ups_service",
  "XTracker::Schema::Result::Public::UpsService",
  { id => "ups_service_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DZBktL8FZq9g7wZ58ynkHw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
