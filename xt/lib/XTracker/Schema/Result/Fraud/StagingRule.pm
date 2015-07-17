use utf8;
package XTracker::Schema::Result::Fraud::StagingRule;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.staging_rule");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fraud.staging_rule_id_seq",
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
  "rule_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "action_order_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "live_rule_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "metric_used",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "metric_decided",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "tag_list",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("staging_rule_rule_sequence_key", ["rule_sequence"]);
__PACKAGE__->belongs_to(
  "action_order_status",
  "XTracker::Schema::Result::Public::OrderStatus",
  { id => "action_order_status_id" },
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
  "live_rule",
  "XTracker::Schema::Result::Fraud::LiveRule",
  { id => "live_rule_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "rule_status",
  "XTracker::Schema::Result::Fraud::RuleStatus",
  { id => "rule_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "staging_conditions",
  "XTracker::Schema::Result::Fraud::StagingCondition",
  { "foreign.rule_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZtAnvWbDJF+SZJTWWdWb3A


use JSON;

__PACKAGE__->inflate_column( 'tag_list', {
    inflate => sub { decode_json( shift ) },
    deflate => sub { encode_json( shift ) },
} );


use Moose;
with 'XTracker::Schema::Role::Result::FraudRule';

sub get_all_conditions {
    my $self = shift;

    return $self->staging_conditions->search(
        { },
        {
            order_by => 'me.id ASC',
        }
    );
}

1;
