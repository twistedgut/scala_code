use utf8;
package XTracker::Schema::Result::Public::Role;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.role");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "role_sequence",
  },
  "role_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("role_role_name_key", ["role_name"]);
__PACKAGE__->has_many(
  "operator_roles",
  "XTracker::Schema::Result::Public::OperatorRole",
  { "foreign.role_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/Zj5mJiBPC64WuHZQBmsNQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;