use utf8;
package XTracker::Schema::Result::Public::DeliveryAction;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.delivery_action");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "delivery_action_id_seq",
  },
  "action",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "rank",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("delivery_action_action_key", ["action"]);
__PACKAGE__->add_unique_constraint("delivery_action_rank_key", ["rank"]);
__PACKAGE__->has_many(
  "log_deliveries",
  "XTracker::Schema::Result::Public::LogDelivery",
  { "foreign.delivery_action_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:osINL3HKP/8KJmiEk0hdFA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
