use utf8;
package XTracker::Schema::Result::Public::BulkOrderActionLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.bulk_order_action_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "bulk_order_action_log_id_seq",
  },
  "action_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "action",
  "XTracker::Schema::Result::Public::BulkOrderAction",
  { id => "action_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "order_status_logs",
  "XTracker::Schema::Result::Public::OrderStatusLog",
  { "foreign.bulk_order_action_log_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cY9kjRAf/nge3MROz9u3+A

sub channel {
    my $self = shift;
    return $self->order_status_logs->first->order->channel;
}

sub operator {
    my $self = shift;
    return $self->order_status_logs->first->operator;
}

1;
