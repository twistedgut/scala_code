use utf8;
package XTracker::Schema::Result::Public::StockCountControl;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.stock_count_control");
__PACKAGE__->add_columns(
  "pick_counting",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "return_counting",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Zp7Le1GhxOxO3PEBYRhe5A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
