use utf8;
package XTracker::Schema::Result::Public::CustomerCategory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.customer_category");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "customer_category_id_seq",
  },
  "category",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "discount",
  {
    data_type => "numeric",
    default_value => 0,
    is_nullable => 1,
    size => [10, 3],
  },
  "is_visible",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "customer_class_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "fast_track",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("customer_category_category_key", ["category"]);
__PACKAGE__->has_many(
  "customer_category_defaults",
  "XTracker::Schema::Result::Public::CustomerCategoryDefault",
  { "foreign.category_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "customer_class",
  "XTracker::Schema::Result::Public::CustomerClass",
  { id => "customer_class_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "customers",
  "XTracker::Schema::Result::Public::Customer",
  { "foreign.category_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_marketing_promotion__customer_categories",
  "XTracker::Schema::Result::Public::LinkMarketingPromotionCustomerCategory",
  { "foreign.customer_category_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wpqiIqYv239tR+B0b9gA3w


# You can replace this text with custom content, and it will be preserved on regeneration
1;
