use utf8;
package XTracker::Schema::Result::Public::PutawayType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.putaway_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "putaway_type_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("putaway_type_name_key", ["name"]);
__PACKAGE__->has_many(
  "stock_processes",
  "XTracker::Schema::Result::Public::StockProcess",
  { "foreign.putaway_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:U+R2SoGO3++GEqwAKqemwQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
