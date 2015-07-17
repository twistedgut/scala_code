use utf8;
package XTracker::Schema::Result::Public::TaxRule;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.tax_rule");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "tax_rule_id_seq",
  },
  "rule",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "tax_rule_values",
  "XTracker::Schema::Result::Public::TaxRuleValue",
  { "foreign.tax_rule_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mJwKopdN5XTGMPGdU0tNrw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
