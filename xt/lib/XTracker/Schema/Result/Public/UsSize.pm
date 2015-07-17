use utf8;
package XTracker::Schema::Result::Public::UsSize;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.us_size");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "us_size_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "std_group_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "rank",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("us_size_name_key", ["name", "std_group_id"]);
__PACKAGE__->add_unique_constraint("us_size_rank_key", ["rank", "std_group_id"]);
__PACKAGE__->belongs_to(
  "std_group",
  "XTracker::Schema::Result::Public::StdGroup",
  { id => "std_group_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "us_size_mappings",
  "XTracker::Schema::Result::Public::UsSizeMapping",
  { "foreign.us_size_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZPRDPVpwNOnJTWg6ROMIYQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
