use utf8;
package XTracker::Schema::Result::Public::ShipRestriction;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.ship_restriction");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "ship_restriction_id_seq",
  },
  "title",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 10 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("ship_restriction_code_key", ["code"]);
__PACKAGE__->has_many(
  "link_product__ship_restrictions",
  "XTracker::Schema::Result::Public::LinkProductShipRestriction",
  { "foreign.ship_restriction_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "ship_restriction_allowed_countries",
  "XTracker::Schema::Result::Public::ShipRestrictionAllowedCountry",
  { "foreign.ship_restriction_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "ship_restriction_allowed_shipping_charges",
  "XTracker::Schema::Result::Public::ShipRestrictionAllowedShippingCharge",
  { "foreign.ship_restriction_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "ship_restriction_exclude_postcodes",
  "XTracker::Schema::Result::Public::ShipRestrictionExcludePostcode",
  { "foreign.ship_restriction_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IPmIkUQzH14lFIWvCw9TDg

1;
