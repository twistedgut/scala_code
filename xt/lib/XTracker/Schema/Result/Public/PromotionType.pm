use utf8;
package XTracker::Schema::Result::Public::PromotionType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.promotion_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "promotion_type_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "product_type",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "weight",
  { data_type => "numeric", is_nullable => 1, size => [10, 2] },
  "fabric",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "origin",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "hs_code",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "promotion_class_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("promotion_type_name_channel_id_key", ["name", "channel_id"]);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "country_promotion_type_welcome_packs",
  "XTracker::Schema::Result::Public::CountryPromotionTypeWelcomePack",
  { "foreign.promotion_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "language__promotion_types",
  "XTracker::Schema::Result::Public::LanguagePromotionType",
  { "foreign.promotion_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "marketing_promotions",
  "XTracker::Schema::Result::Public::MarketingPromotion",
  { "foreign.promotion_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "order_promotions",
  "XTracker::Schema::Result::Public::OrderPromotion",
  { "foreign.promotion_type_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "promotion_class",
  "XTracker::Schema::Result::Public::PromotionClass",
  { id => "promotion_class_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->many_to_many("languages", "language__promotion_types", "language");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:o7tmx+hLTVuvw6XKJGhZMw

__PACKAGE__->many_to_many(
    'countries', country_promotion_type_welcome_packs => 'country'
);

1;
