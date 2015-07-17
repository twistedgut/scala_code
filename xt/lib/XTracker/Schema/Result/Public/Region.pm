use utf8;
package XTracker::Schema::Result::Public::Region;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.region");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "region_id_seq",
  },
  "region",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "price_regions",
  "XTracker::Schema::Result::Public::PriceRegion",
  { "foreign.region_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "region_charges",
  "XTracker::Schema::Result::Shipping::RegionCharge",
  { "foreign.region_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sub_regions",
  "XTracker::Schema::Result::Public::SubRegion",
  { "foreign.region_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:saNKsFd/Zn2sK+IXQipCgg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
