use utf8;
package XTracker::Schema::Result::Public::PostcodeShippingCharge;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.postcode_shipping_charge");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "postcode_shipping_charge_id_seq",
  },
  "postcode",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipping_charge_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "country",
  "XTracker::Schema::Result::Public::Country",
  { id => "country_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipping_charge",
  "XTracker::Schema::Result::Public::ShippingCharge",
  { id => "shipping_charge_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Rfn7XXhXGIptxt4MxwZPFQ

1;
