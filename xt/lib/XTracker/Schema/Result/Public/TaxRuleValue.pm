use utf8;
package XTracker::Schema::Result::Public::TaxRuleValue;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.tax_rule_value");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "tax_rule_value_id_seq",
  },
  "tax_rule_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("uix_country_tax", ["tax_rule_id", "country_id"]);
__PACKAGE__->belongs_to(
  "country",
  "XTracker::Schema::Result::Public::Country",
  { id => "country_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "tax_rule",
  "XTracker::Schema::Result::Public::TaxRule",
  { id => "tax_rule_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZvxZV3FK5bh6SpjYpA4WsA

__PACKAGE__->add_unique_constraint("uix_country_tax", ["tax_rule_id", "country_id"]);

1;
