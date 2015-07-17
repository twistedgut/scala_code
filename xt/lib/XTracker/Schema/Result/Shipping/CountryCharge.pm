use utf8;
package XTracker::Schema::Result::Shipping::CountryCharge;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("shipping.country_charge");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipping.country_charge_id_seq",
  },
  "shipping_charge_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "currency_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "charge",
  { data_type => "numeric", is_nullable => 1, size => [10, 2] },
);
__PACKAGE__->add_unique_constraint(
  "country_charge_shipping_charge_id_country_id_currency_id_key",
  ["shipping_charge_id", "country_id", "currency_id"],
);
__PACKAGE__->belongs_to(
  "country",
  "XTracker::Schema::Result::Public::Country",
  { id => "country_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "currency",
  "XTracker::Schema::Result::Public::Currency",
  { id => "currency_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
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


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9AkiHHXH3g8CfHrZ+DD/sg

# FIXME: Not actually a primary key in the database
__PACKAGE__->set_primary_key('id');

1;
