use utf8;
package XTracker::Schema::Result::Public::CustomerActionType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.customer_action_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "customer_action_type_id_seq",
  },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 50 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("customer_action_type_type_key", ["type"]);
__PACKAGE__->has_many(
  "customer_actions",
  "XTracker::Schema::Result::Public::CustomerAction",
  { "foreign.customer_action_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vPFtKJ9sRvRsAllC74La3g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
