use utf8;
package XTracker::Schema::Result::Public::BulkOrderAction;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.bulk_order_action");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "bulk_order_action_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("bulk_order_action_name_key", ["name"]);
__PACKAGE__->has_many(
  "bulk_order_action_logs",
  "XTracker::Schema::Result::Public::BulkOrderActionLog",
  { "foreign.action_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FyM4z5IxhMM4qPBZB97xdg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
