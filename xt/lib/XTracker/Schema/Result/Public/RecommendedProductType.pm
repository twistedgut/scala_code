use utf8;
package XTracker::Schema::Result::Public::RecommendedProductType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.recommended_product_type");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 100 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "recommended_products",
  "XTracker::Schema::Result::Public::RecommendedProduct",
  { "foreign.type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hMKEHIumzCSZ16a9lpyJjw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
