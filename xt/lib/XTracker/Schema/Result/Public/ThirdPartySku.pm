use utf8;
package XTracker::Schema::Result::Public::ThirdPartySku;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.third_party_sku");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "third_party_sku_id_seq",
  },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "business_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "third_party_sku",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("business_id_sku_key", ["business_id", "third_party_sku"]);
__PACKAGE__->add_unique_constraint("variant_id_key", ["variant_id"]);
__PACKAGE__->belongs_to(
  "business",
  "XTracker::Schema::Result::Public::Business",
  { id => "business_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xTQ9hVD4ySN0Q077rSGO2w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
