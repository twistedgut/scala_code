use utf8;
package XTracker::Schema::Result::Public::LinkMarketingPromotionCustomerSegment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_marketing_promotion__customer_segment");
__PACKAGE__->add_columns(
  "marketing_promotion_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "customer_segment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->add_unique_constraint(
  "link_marketing_promotion__cus_marketing_promotion_id_custom_key",
  ["marketing_promotion_id", "customer_segment_id"],
);
__PACKAGE__->belongs_to(
  "customer_segment",
  "XTracker::Schema::Result::Public::MarketingCustomerSegment",
  { id => "customer_segment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "marketing_promotion",
  "XTracker::Schema::Result::Public::MarketingPromotion",
  { id => "marketing_promotion_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:o1vPJ5568Dye6aw7Sfm6Hg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
