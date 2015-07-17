use utf8;
package XTracker::Schema::Result::Public::StockCountCategory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.stock_count_category");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "stock_count_category_id_seq",
  },
  "category",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "priority",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "stock_count_variants",
  "XTracker::Schema::Result::Public::StockCountVariant",
  { "foreign.stock_count_category_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yUFUGrSmr2F5IpTm6zZR8w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
