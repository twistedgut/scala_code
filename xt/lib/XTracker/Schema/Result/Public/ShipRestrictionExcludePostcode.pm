use utf8;
package XTracker::Schema::Result::Public::ShipRestrictionExcludePostcode;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.ship_restriction_exclude_postcode");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "ship_restriction_exclude_postcode_id_seq",
  },
  "ship_restriction_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "postcode",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "ship_restriction_exclude_post_ship_restriction_id_postcode__key",
  ["ship_restriction_id", "postcode", "country_id"],
);
__PACKAGE__->belongs_to(
  "country",
  "XTracker::Schema::Result::Public::Country",
  { id => "country_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "ship_restriction",
  "XTracker::Schema::Result::Public::ShipRestriction",
  { id => "ship_restriction_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:p1VA9VAcVEbqgWEyCxngJg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
