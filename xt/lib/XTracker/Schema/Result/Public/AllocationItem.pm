use utf8;
package XTracker::Schema::Result::Public::AllocationItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.allocation_item");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "allocation_item_id_seq",
  },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipment_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "allocation_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "picked_at",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "picked_by",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "picked_into",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "delivered_at",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "actual_prl_delivery_destination_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "delivery_order",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "actual_prl_delivery_destination",
  "XTracker::Schema::Result::Public::PrlDeliveryDestination",
  { id => "actual_prl_delivery_destination_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "allocation",
  "XTracker::Schema::Result::Public::Allocation",
  { id => "allocation_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "allocation_item_logs",
  "XTracker::Schema::Result::Public::AllocationItemLog",
  { "foreign.allocation_item_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "integration_container_items",
  "XTracker::Schema::Result::Public::IntegrationContainerItem",
  { "foreign.allocation_item_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "shipment_item",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { id => "shipment_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::AllocationItemStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7Aqkrw87T6USryhaa6/dkw

use MooseX::Params::Validate 'validated_list';

use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

use XTracker::Constants::FromDB qw/
    :allocation_item_status
    :container_status
    :integration_container_item_status
/;

=head1 PICKED_ FIELDS

The C<picked_> fields are for keeping track of data sent to us via ItemPicked
messages.

=head2 picked_at

Starts life as NULL, but we expect it will always be set via C<NOW()> when an
ItemPicked message is received.

=head2 picked_by

This is just a string containing the name of the user the PRL saw pick the item.
There is no sensible mapping of this back to XT users, and this string is for
human - rather than machine - consumption.

=head2 picked_into

We don't link this field to a container -  we use it to set the shipment_item's
(to which this allocation_item refers) container_id when we get a ContainerReady
message in the future, and it's the shipment_item - with all the magic around
its `pick_into` method, that'll handle things like creating the container
appropriately. This value is simply meant to reflect what was in the message we
received.

=head2 METHODS

=head2 variant

C<<->shipment_item->variant>>

=cut

sub variant_or_voucher_variant {
    $_[0]->shipment_item->variant ||
    $_[0]->shipment_item->voucher_variant
}

=head2 is_active

True unless its status is one marked as an end state.

=cut

sub is_active { ! $_[0]->status->is_end_state }

=head2 is_allocated

Return a true value if the allocation status is B<Allocated>.

=cut

sub is_allocated { return shift->status_id == $ALLOCATION_ITEM_STATUS__ALLOCATED; }

=head2 is_picked

Return a true value if the allocation status is B<Picked>.

=cut

sub is_picked { shift->status_id == $ALLOCATION_ITEM_STATUS__PICKED; }

=head2 is_picking

Return a true value if the allocation status is B<Picking>.

=cut

sub is_picking { shift->status_id == $ALLOCATION_ITEM_STATUS__PICKING; }

=head2 is_short_picked

Return a true value if the allocation status is B<Short>.

=cut

sub is_short_picked { shift->status_id == $ALLOCATION_ITEM_STATUS__SHORT; }

=head2 update_status

Updates the status and logs that the status changed, if appropriate.

=cut

sub update_status {
    my ($self, $new_status, $operator_id) = @_;

    return if ($self->status_id == $new_status);

    $self->result_source->schema->txn_do(
        sub {
            $self->update({ status_id => $new_status });
            $self->log_status($operator_id);
        }
    );

    return $self;
}

=head2 log_status

Log a change in the allocation, or the allocation item's status

=cut

sub log_status {
    my ($self, $operator_id) = @_;

    $self->discard_changes unless defined($self->id);

    my $schema = $self->result_source->schema;
    my $allocation = $self->allocation;

    eval {

        $schema->resultset('Public::AllocationItemLog')->create({
            operator_id               => $operator_id,
            allocation_item_id        => $self->id,
            allocation_item_status_id => $self->status_id,
            allocation_status_id      => $allocation->status_id,
            date                      => \'statement_timestamp()',
        });

    };

    if ($@) {
        require Carp;
        Carp::confess('cant bulk insert allocation item log entries');
    }

    return $self;
}

=head2 add_to_integration_container($integration_container_row) : $integration_container_item | die

Add a picked allocation item to a container at integration. Die if
this allocation item cannot be picked into this container.

The shipment item's container id is also updated.

=cut

sub add_to_integration_container {
    my ($self, $integration_container_row, $is_missing) = validated_list(
        \@_,
        integration_container => {
            isa => 'XTracker::Schema::Result::Public::IntegrationContainer',
        },
        is_missing => {
            isa      => 'Bool',
            optional => 1,
            default  => 0,
        },
    );

    # make sure Integration container record exists in the DB
    unless ($integration_container_row->in_storage){
        $self->result_source->schema->resultset('Public::Container')
            ->find_or_create({
                id => $integration_container_row->container_id,
            });
        $integration_container_row->insert;
    }

    $self->validate_add_to_integration_container({
        integration_container => $integration_container_row
    });

    $self->shipment_item->update({
        container_id => $integration_container_row->container_id
    });
    $integration_container_row->container->update({
        status_id => $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS
    });

    my $integration_container_item_args = {
        integration_container_id => $integration_container_row->id,
        status_id                => $INTEGRATION_CONTAINER_ITEM_STATUS__INTEGRATED,
    };
    $integration_container_item_args->{status_id} =
        $INTEGRATION_CONTAINER_ITEM_STATUS__MISSING
            if $is_missing;

    return $self->create_related(
        integration_container_items => $integration_container_item_args,
    );
}

=head2 validate_add_to_integration_container($integration_container_row) : undef | die

Check that the allocation item can be added to this container. Die with
useful message if not.

Things that are checked:
* the container hasn't already been completed
* the item isn't already in a container (completed or not)
* the item can be mixed with other items already in the container

=cut

sub validate_add_to_integration_container {
    my ($self, $integration_container_row) = validated_list(
        \@_,
        integration_container     => { isa => 'XTracker::Schema::Result::Public::IntegrationContainer' },
    );

    # Check that the integration container can accept items
    if ($integration_container_row->is_complete) {
        die sprintf("Container [%s] has already been completed, please do not add more items to it. Send container to packing\n", $integration_container_row->container_id);
    }

    # Check that the item isn't already in a container
    if (my $existing = $self->integration_container_items->first) {
        if ($existing->integration_container->is_complete) {
            die sprintf("This item has already been sent to packing in container [%s]\n", $existing->integration_container->container_id);
        } else {
            die sprintf("This item is already in container [%s], please resume working with that container\n",  $existing->integration_container->container_id);
        }
    }

    # Delegate to the container to check the other standard rules
    # picked items.
    $integration_container_row->container->validate_pick_into({
        shipment_item         => $self->shipment_item,
    });

    return;
}
1;
