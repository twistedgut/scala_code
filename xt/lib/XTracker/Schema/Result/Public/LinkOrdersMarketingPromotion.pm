use utf8;
package XTracker::Schema::Result::Public::LinkOrdersMarketingPromotion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_orders__marketing_promotion");
__PACKAGE__->add_columns(
  "orders_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "marketing_promotion_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->add_unique_constraint(
  "link_orders__marketing_promot_orders_id_marketing_promotion_key",
  ["orders_id", "marketing_promotion_id"],
);
__PACKAGE__->belongs_to(
  "marketing_promotion",
  "XTracker::Schema::Result::Public::MarketingPromotion",
  { id => "marketing_promotion_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "order",
  "XTracker::Schema::Result::Public::Orders",
  { id => "orders_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kldqGB0Zb/S30VB0x7TESA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
