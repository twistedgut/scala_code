use utf8;
package XTracker::Schema::Result::Public::PriceAdjustmentCategory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.price_adjustment_category");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "price_adjustment_category_id_seq",
  },
  "category",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "price_adjustments",
  "XTracker::Schema::Result::Public::PriceAdjustment",
  { "foreign.category_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QQT81I1XjsCM2u9qqIs3sg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
