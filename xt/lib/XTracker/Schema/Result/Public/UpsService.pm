use utf8;
package XTracker::Schema::Result::Public::UpsService;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.ups_service");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "ups_service_id_seq",
  },
  "code",
  { data_type => "text", is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 0 },
  "shipping_charge_class_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "ups_service_code_shipping_charge_class_id_key",
  ["code", "shipping_charge_class_id"],
);
__PACKAGE__->belongs_to(
  "shipping_charge_class",
  "XTracker::Schema::Result::Public::ShippingChargeClass",
  { id => "shipping_charge_class_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "ups_service_availabilities",
  "XTracker::Schema::Result::Public::UpsServiceAvailability",
  { "foreign.ups_service_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4Rsp1votQFTghn8tQdjL8Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
