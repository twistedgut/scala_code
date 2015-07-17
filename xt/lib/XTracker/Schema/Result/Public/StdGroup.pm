use utf8;
package XTracker::Schema::Result::Public::StdGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.std_group");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "std_group_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("std_group_name_key", ["name"]);
__PACKAGE__->has_many(
  "std_sizes",
  "XTracker::Schema::Result::Public::StdSize",
  { "foreign.std_group_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "us_sizes",
  "XTracker::Schema::Result::Public::UsSize",
  { "foreign.std_group_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HYtNyJDMoCzr++D0y+fLag


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
