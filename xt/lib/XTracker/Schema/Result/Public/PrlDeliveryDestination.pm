use utf8;
package XTracker::Schema::Result::Public::PrlDeliveryDestination;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.prl_delivery_destination");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "prl_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "message_name",
  { data_type => "text", is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "allocation_items",
  "XTracker::Schema::Result::Public::AllocationItem",
  { "foreign.actual_prl_delivery_destination_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "allocations",
  "XTracker::Schema::Result::Public::Allocation",
  { "foreign.prl_delivery_destination_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "prl",
  "XTracker::Schema::Result::Public::Prl",
  { id => "prl_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:j7aTwgFe0Y0g14bBqtBUxg

use XTracker::Constants::FromDB qw/
    :prl_delivery_destination
    :allocation_status
/;

our ($PRL_DELIVERY_DESTINATION__GOH_DIRECT);

=head2 allows_single_item_grouping : 0|1

does this delivery destination allow single-item shipments to be grouped.

=cut

sub allows_single_item_grouping {
    my $self = shift;

    return $self->id == $PRL_DELIVERY_DESTINATION__GOH_DIRECT;
}

=head2 get_allocation_items_at_destination() : $allocation_items_rs

Return result set with allocation items that are at current destination.

=cut

sub allocation_items_at_destination {
    $_[0]->allocation_items->filter_delivered->filter_non_integrated;
}

1;
