use utf8;
package XTracker::Schema::Result::Public::LinkMarketingPromotionGenderProxy;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_marketing_promotion__gender_proxy");
__PACKAGE__->add_columns(
  "marketing_promotion_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "gender_proxy_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "include",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("marketing_promotion_id", "gender_proxy_id");
__PACKAGE__->belongs_to(
  "gender_proxy",
  "XTracker::Schema::Result::Public::MarketingGenderProxy",
  { id => "gender_proxy_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "marketing_promotion",
  "XTracker::Schema::Result::Public::MarketingPromotion",
  { id => "marketing_promotion_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sxDw7gYobE6VYEPE3vOnnQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
