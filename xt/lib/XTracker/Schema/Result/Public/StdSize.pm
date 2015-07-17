use utf8;
package XTracker::Schema::Result::Public::StdSize;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.std_size");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "std_size_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "std_group_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "rank",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("std_size_name_key", ["name", "std_group_id"]);
__PACKAGE__->add_unique_constraint("std_size_rank_key", ["rank", "std_group_id"]);
__PACKAGE__->belongs_to(
  "std_group",
  "XTracker::Schema::Result::Public::StdGroup",
  { id => "std_group_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "std_size_mappings",
  "XTracker::Schema::Result::Public::StdSizeMapping",
  { "foreign.std_size_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "variants",
  "XTracker::Schema::Result::Public::Variant",
  { "foreign.std_size_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gMjx+yPCG1tHPN7RhTbOqA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
