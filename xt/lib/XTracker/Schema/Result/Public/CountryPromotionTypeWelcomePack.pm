use utf8;
package XTracker::Schema::Result::Public::CountryPromotionTypeWelcomePack;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.country_promotion_type_welcome_pack");
__PACKAGE__->add_columns(
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "promotion_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->add_unique_constraint(
  "idx_country_promo_type_welcome_pack_country_id_promo_type_id",
  ["country_id", "promotion_type_id"],
);
__PACKAGE__->belongs_to(
  "country",
  "XTracker::Schema::Result::Public::Country",
  { id => "country_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "promotion_type",
  "XTracker::Schema::Result::Public::PromotionType",
  { id => "promotion_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:USD1AaJ4TwcsKriN8XRvJA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
