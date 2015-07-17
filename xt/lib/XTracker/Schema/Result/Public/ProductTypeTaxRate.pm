use utf8;
package XTracker::Schema::Result::Public::ProductTypeTaxRate;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.product_type_tax_rate");
__PACKAGE__->add_columns(
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "product_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "rate",
  {
    data_type => "numeric",
    default_value => "0.000",
    is_nullable => 0,
    size => [10, 3],
  },
  "fulcrum_reporting_id",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("country_id", "product_type_id");
__PACKAGE__->belongs_to(
  "country",
  "XTracker::Schema::Result::Public::Country",
  { id => "country_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "product_type",
  "XTracker::Schema::Result::Public::ProductType",
  { id => "product_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9/yjcs6NrbBs1dPNJM5Jrw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
