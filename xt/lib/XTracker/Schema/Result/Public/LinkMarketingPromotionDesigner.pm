use utf8;
package XTracker::Schema::Result::Public::LinkMarketingPromotionDesigner;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_marketing_promotion__designer");
__PACKAGE__->add_columns(
  "marketing_promotion_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "designer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "include",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
);
__PACKAGE__->add_unique_constraint(
  "link_marketing_promotion__des_marketing_promotion_id_design_key",
  ["marketing_promotion_id", "designer_id"],
);
__PACKAGE__->belongs_to(
  "designer",
  "XTracker::Schema::Result::Public::Designer",
  { id => "designer_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "marketing_promotion",
  "XTracker::Schema::Result::Public::MarketingPromotion",
  { id => "marketing_promotion_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8bFbaSi6hXE70S9UAVqsLQ


1;
