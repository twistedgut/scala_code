use utf8;
package XTracker::Schema::Result::Fraud::ArchivedRule;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.archived_rule");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fraud.archived_rule_id_seq",
  },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "rule_sequence",
  { data_type => "integer", is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "start_date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "end_date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "enabled",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "action_order_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "metric_used",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "metric_decided",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "change_log_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "created_by_operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "expired",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "expired_by_operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "tag_list",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "action_order_status",
  "XTracker::Schema::Result::Public::OrderStatus",
  { id => "action_order_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "archived_conditions",
  "XTracker::Schema::Result::Fraud::ArchivedCondition",
  { "foreign.rule_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "change_log",
  "XTracker::Schema::Result::Fraud::ChangeLog",
  { id => "change_log_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "created_by_operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "created_by_operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "expired_by_operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "expired_by_operator_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "live_rules",
  "XTracker::Schema::Result::Fraud::LiveRule",
  { "foreign.archived_rule_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "orders_rule_outcomes",
  "XTracker::Schema::Result::Fraud::OrdersRuleOutcome",
  { "foreign.archived_rule_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IPsV7D3S1N8dsH2L707LzA


use JSON;

__PACKAGE__->inflate_column( 'tag_list', {
    inflate => sub { decode_json( shift ) },
    deflate => sub { encode_json( shift ) },
} );


use Moose;
with 'XTracker::Schema::Role::Result::FraudRule';


1;
