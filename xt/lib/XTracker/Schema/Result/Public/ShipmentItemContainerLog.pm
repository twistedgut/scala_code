use utf8;
package XTracker::Schema::Result::Public::ShipmentItemContainerLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipment_item_container_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipment_item_container_log_id_seq",
  },
  "shipment_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "old_container_id",
  { data_type => "text", is_nullable => 1 },
  "new_container_id",
  { data_type => "text", is_nullable => 1 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment_item",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { id => "shipment_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:R3Pas6w+HSondYcLRUekig

__PACKAGE__->belongs_to(
    old_container => 'XTracker::Schema::Result::Public::Container',
    { 'foreign.id' => 'self.old_container_id' }
);

__PACKAGE__->belongs_to(
    new_container => 'XTracker::Schema::Result::Public::Container',
    { 'foreign.id' => 'self.new_container_id' }
);

=head1 NAME

XTracker::Schema::Result::Public::ShipmentItemContainerLog

=head1 METHODS

=head2 status_message() : $message

Return a status message describing the action.

=cut

sub status_message {
    my $self = shift;
    return sprintf( q{Moved from container '%s' to container '%s'},
        $self->old_container_id, $self->new_container_id
    ) if 2 == grep { defined $self->$_ } qw/new_container_id old_container_id/;

    return sprintf(q{Put into container '%s'},$self->new_container_id)
        if defined $self->new_container_id;

    return sprintf(q{Removed from container '%s'},$self->old_container_id)
        if defined $self->old_container_id;

    # Should never reach here
    die sprintf
        'Programmer error: Neither old_container_id nor new_container_id is defined (id: %d)',
        $self->id;
}

1;
