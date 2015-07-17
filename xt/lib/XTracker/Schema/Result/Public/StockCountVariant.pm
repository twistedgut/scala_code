use utf8;
package XTracker::Schema::Result::Public::StockCountVariant;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.stock_count_variant");
__PACKAGE__->add_columns(
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "location_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "stock_count_category_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "last_count",
  { data_type => "timestamp", is_nullable => 1 },
);
__PACKAGE__->belongs_to(
  "location",
  "XTracker::Schema::Result::Public::Location",
  { id => "location_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "stock_count_category",
  "XTracker::Schema::Result::Public::StockCountCategory",
  { id => "stock_count_category_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3yCuPqC2AdiJYcZRcmFh/w

1;
