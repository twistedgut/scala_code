use utf8;
package XTracker::Schema::Result::Public::OrderStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.order_status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "order_status_id_seq",
  },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "fraud_archived_rules",
  "XTracker::Schema::Result::Fraud::ArchivedRule",
  { "foreign.action_order_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "fraud_live_rules",
  "XTracker::Schema::Result::Fraud::LiveRule",
  { "foreign.action_order_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "fraud_staging_rules",
  "XTracker::Schema::Result::Fraud::StagingRule",
  { "foreign.action_order_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "order_status_logs",
  "XTracker::Schema::Result::Public::OrderStatusLog",
  { "foreign.order_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "orders",
  "XTracker::Schema::Result::Public::Orders",
  { "foreign.order_status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:K8C6rm9bYQ9ZPM1KSTH8IA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
