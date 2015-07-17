use utf8;
package XTracker::Schema::Result::Public::OperatorRole;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.operator_role");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "operator_role_sequence",
  },
  "operator_id",
  { data_type => "integer", is_nullable => 0 },
  "role_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "role",
  "XTracker::Schema::Result::Public::Role",
  { id => "role_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vRe6hUFD8fSkNsSObhHRag

__PACKAGE__->belongs_to(
    'operator' => 'Public::Operator',
    { 'foreign.id' => 'self.operator_id' },
);

1;
