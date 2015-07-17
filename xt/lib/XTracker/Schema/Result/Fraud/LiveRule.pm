use utf8;
package XTracker::Schema::Result::Fraud::LiveRule;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.live_rule");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fraud.live_rule_id_seq",
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
  "archived_rule_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "tag_list",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("live_rule_rule_sequence_key", ["rule_sequence"]);
__PACKAGE__->belongs_to(
  "action_order_status",
  "XTracker::Schema::Result::Public::OrderStatus",
  { id => "action_order_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "archived_rule",
  "XTracker::Schema::Result::Fraud::ArchivedRule",
  { id => "archived_rule_id" },
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
__PACKAGE__->has_many(
  "live_conditions",
  "XTracker::Schema::Result::Fraud::LiveCondition",
  { "foreign.rule_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "staging_rules",
  "XTracker::Schema::Result::Fraud::StagingRule",
  { "foreign.live_rule_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BO44jkkH3UpZWpGeksj8SQ


use JSON;

__PACKAGE__->inflate_column( 'tag_list', {
    inflate => sub { decode_json( shift ) },
    deflate => sub { encode_json( shift ) },
} );


use Moose;
with 'XTracker::Schema::Role::Result::FraudRule';

sub get_all_conditions {
    my $self = shift;

    return $self->live_conditions->search(
        { },
        {
            order_by => 'me.id ASC',
        }
    );
}

1;
