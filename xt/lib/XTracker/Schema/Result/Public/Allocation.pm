use utf8;
package XTracker::Schema::Result::Public::Allocation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.allocation");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "allocation_id_seq",
  },
  "shipment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pick_sent",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "prl_delivery_destination_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "prl_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "allocation_items",
  "XTracker::Schema::Result::Public::AllocationItem",
  { "foreign.allocation_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "prl",
  "XTracker::Schema::Result::Public::Prl",
  { id => "prl_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "prl_delivery_destination",
  "XTracker::Schema::Result::Public::PrlDeliveryDestination",
  { id => "prl_delivery_destination_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "shipment",
  "XTracker::Schema::Result::Public::Shipment",
  { id => "shipment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::AllocationStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:y1mSZUyiSwV183Lw71fmGA


use Carp qw/ confess /;
use Try::Tiny;
use MooseX::Params::Validate;

use Moose;
with 'XTracker::Role::WithAMQMessageFactory';

use Moose;
with 'XTracker::Role::WithAMQMessageFactory';

use XT::Domain::PRLs;
use XTracker::AllocateManager;

use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw/
    :allocation_item_status
    :allocation_status
    :customer_issue_type
    :prl
    :prl_delivery_destination
    :shipment_status
    :shipment_item_status
    :shipment_hold_reason
    :integration_container_item_status
/;

use XTracker::Database::Shipment qw/insert_shipment_note/;
use XTracker::Logfile qw( xt_logger );
use NAP::XT::Exception::Allocation::Unpickable;
use NAP::XT::Exception::Allocation::CannotMarkAsDelivered;

# Symbols that appear in the code, but might not be available in
# XTracker::Constants::FromDB.
our (
  $PRL__GOH,
  $PRL__DEMATIC,
  $PRL_DELIVERY_DESTINATION__GOH_DIRECT,
  $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION,
);

=head2 prl_location

Return the location object for the PRL this allocation is linked to.

=cut

sub prl_location {
    my $self = shift;

    return $self->prl->location;
}

=head2 prl_amq_identifier() : $prl_amq_identifier

Return the config amq_identifier for the PRL of this Allocation.

=cut

sub prl_amq_identifier {
    my $self = shift;
    return $self->prl->amq_identifier;
}


=head2 unpicked_items

Return allocation items that will be picked but haven't been yet.

=cut

sub unpicked_items {
    my $self = shift;

    return $self->allocation_items->filter_active;
}

=head2 pick_complete($operator_id) :

Mark the allocation as being fully picked, from the PRL's perspective. We update
its status, and the status of its allocation items, as well as putting the
shipment on hold, if appropriate.

=cut

sub pick_complete {
    my ($self, $operator_id) = @_;

    my $schema = $self->result_source->schema;

    $schema->txn_do(sub{
        # Update the allocation status. Note that this allocation status
        # applies even when *all* the allocation's items are short. This is a
        # little unexpected (to me, anyway), but that's just how it all works.
        my $new_status = $self->prl->pick_complete_allocation_status;
        $self->update_status($new_status, $operator_id);

        my @unpicked_items = $self->unpicked_items or return;

        # Short any unpicked items
        my $shipment = $self->shipment;
        foreach my $unpicked_item (@unpicked_items) {
            xt_logger->info(
                sprintf q{Allocation item '%i' (allocation '%i') is short},
                    $unpicked_item->id, $self->id
            );
            $unpicked_item->update_status($ALLOCATION_ITEM_STATUS__SHORT, $operator_id);

            # If we have a sample shipment we only have one item, so cancel the
            # shipment (and its item) and we're done
            if ( $shipment->is_sample_shipment ) {
                xt_logger->info(
                    sprintf q{Sample shipment '%i' is being cancelled}, $shipment->id
                );
                $shipment->cancel(
                    operator_id            => $APPLICATION_OPERATOR_ID,
                    customer_issue_type_id => $CUSTOMER_ISSUE_TYPE__8__STOCK_DISCREPANCY,
                    do_pws_update          => 0,
                );
                return;
            }

            # We should only get here if we're dealing with customer shipments
            my $shipment_item = $unpicked_item->shipment_item;
            # - If the shipment_item is still SELECTED (i.e. it hasn't also
            # been cancelled during picking) set its status to NEW so that if
            # we do manage to create a new pickable allocation_item for them
            # later the shipment_item will be in the right state.
            if ($shipment_item->is_selected) {
                $shipment_item->update_status($SHIPMENT_ITEM_STATUS__NEW, $operator_id);
            }
            # - If is has been cancelled during picking its status will be
            # cancel_pending, but we want to update it to cancelled since
            # nothing else can happen to it now (because there is no item
            # to put away).
            if ($shipment_item->is_cancel_pending) {
                $shipment_item->update_status($SHIPMENT_ITEM_STATUS__CANCELLED, $operator_id);
            }
        }

        my $short_msg = $self->_short_msg( @unpicked_items );

        # Hold the shipment, if we can
        if ( $shipment->can_be_put_on_hold && !$shipment->is_held) {
            xt_logger->info(
                sprintf q{Customer shipment '%i' is being held}, $shipment->id
            );
            $shipment->put_on_hold({
                status_id   => $SHIPMENT_STATUS__HOLD,
                reason      => $SHIPMENT_HOLD_REASON__STOCK_DISCREPANCY,
                operator_id => $APPLICATION_OPERATOR_ID,
                norelease   => 1, # Don't set an automatic release date
                # This doesn't actually create a shipment note?!
                comment     => $short_msg,
            });
        }
        # Create the shipment note
        insert_shipment_note(
            $schema->storage->dbh,
            $shipment->id,
            $APPLICATION_OPERATOR_ID,
            $short_msg,
        );
    });
}

# Given a list of items not picked, returns a human-readable summary of the
# short-pick
sub _short_msg {
    my ( $self, @unpicked_items ) = @_;

    my $short_sku_count = {};
    $short_sku_count->{ $_->variant_or_voucher_variant->sku }++
        for @unpicked_items;

    my $short_msg =
        join ";\n",
        # Produce a string from the data
        map {
            sprintf("%d unit%s of SKU %s",
                $_->{'count'},
                (( $_->{'count'} == 1 ) ? '' : 's'),
                $_->{'sku'}, )
        # Turn the hashkey in to sku, and add to the values
        } map {
            { sku => $_, count => $short_sku_count->{ $_ } }
        } keys %{ $short_sku_count };

    # Pad out the short msg a little
    return sprintf(
        "PRL [%s] short-picked the following for allocation [%d]:\n\n%s",
        $self->prl->name,
        $self->id,
        $short_msg,
    );
}

=head2 allocate_pack_space() : 1 | die

Assuming the allocation is in ALLOCATING_PACK_SPACE, transition to the
next status, which should count as having allocated pack space.

Die if in the wrong status.

=cut

sub allocate_pack_space {
    my $self = shift;
    $self->status_id == $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE or confess(
        "Can't allocate pack space, allocation (@{[ $self->id ]}) is in "
        . "status (@{[ $self->status->status ]}), not (allocating_pack_space)",
    );

    # Start the prepare/deliver process if it's in a PRL that supports it, and
    # there are picked items to be prepared.
    # TODO DCA-4265: Remove hardcoded check for $PRL__GOH
    if ($self->prl_id == $PRL__GOH && $self->allocation_items->filter_picked->count) {
        $self->send_prepare_message;
    }

    return 1;
}

=head2 picking_mix_group

Used to determine which items can be put in the same container.
Two items with the same picking mix group string must not be put in the same
container.

Returns a string.

=cut

sub picking_mix_group {
    my ($self) = @_;
    my $mix_group;
    try {
        my $order_or_stock_transfer = $self->shipment->order ||
                         $self->shipment->link_stock_transfer__shipment->stock_transfer;

        $mix_group = $order_or_stock_transfer->channel->business->config_section;
        $mix_group .= $self->shipment->is_transfer_shipment ?
                    '_Sample_'.$order_or_stock_transfer->type->type :
                    '_'.$self->shipment->shipment_type->type;

        my $physical_item_count = scalar $self->shipment->get_physical_items;
        if ($physical_item_count != 1) {
            $mix_group .= '-'.$self->shipment->id.'-'.$self->id;
        }
    } catch {
        # If something has gone wrong we'll just use the allocation id.
        # This will prevent any consolidation of shipments but that's better
        # than just giving up.
        xt_logger->warn("Problem finding mix group for allocation ".$self->id.": ".$_);
        $mix_group = $self->id;
    };
    return $mix_group;
}

=head2 integration_mix_group : $string_with_mix_group

Return string with mix group that is used while deciding whether or not
allocation items are suitable to be placed together at GOH Integration.

Integration container should only have allocation items with the same
Integration mix group.

=cut

sub integration_mix_group {
    my $self = shift;

    # for single item shipments use picking mix group as it cares
    # about Samples, premier orders etc (that is they are not
    # mixed with others)
    return $self->picking_mix_group
        unless $self->shipment->is_multi_item;

    return 'MULTI_ITEM_' . $self->shipment->id;
}

=head2 packing_summary : $packing_summary_string | undef

Return packing_status for the Allocation if it isn't yet picked into a
Container (if it's in a Container, the Container packing_status is
more interesting).

=cut

sub packing_summary {
    my $self = shift;
    my $message = {
        $ALLOCATION_STATUS__REQUESTED => "awaiting allocation",
        $ALLOCATION_STATUS__ALLOCATED => "allocated",
        $ALLOCATION_STATUS__PICKING   => "being picked",
    }->{ $self->status_id } or return undef;

    my $prl_name = $self->prl->name // "";
    $prl_name &&= "in $prl_name";
    my $allocation_id = $self->id;
    return "Allocation $allocation_id is $message $prl_name PRL";
}

=head2 waiting_summary : $waiting_summary_string | undef

Return some detail of what's happening with this allocation that is
useful if we're waiting for it (for use from multi-tote pack lane
activity page).

=cut

sub waiting_summary {
    my $self = shift;

    my $prl_name = $self->prl->name // "";
    my $allocation_id = $self->id;

    if ($self->status_id == $ALLOCATION_STATUS__STAGED) {
        return "Waiting for allocation $allocation_id to be inducted";
    } elsif ($self->status_id == $ALLOCATION_STATUS__REQUESTED ||
             $self->status_id == $ALLOCATION_STATUS__ALLOCATED ||
             $self->status_id == $ALLOCATION_STATUS__PICKING) {
        return "Waiting for allocation $allocation_id in $prl_name PRL";
    }
}

=head2 is_requested

Return a true value if the allocation status is B<Requested>.

=cut

sub is_requested { return shift->status_id == $ALLOCATION_STATUS__REQUESTED; }

=head2 is_allocated

Return a true value if the allocation status is B<Allocated>.

=cut

sub is_allocated { return shift->status_id == $ALLOCATION_STATUS__ALLOCATED; }

=head2 is_picking

Return a true value if the allocation status is B<Picking>.

=cut

sub is_picking { shift->status_id == $ALLOCATION_STATUS__PICKING; }

=head2 is_allocating_pack_space

Return a true value if the allocation status is B<Allocating_Pack_Space>.

=cut

sub is_allocating_pack_space { return shift->status_id == $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE; }

=head2 is_staged

Return a true value if the allocation status is B<Staged>.

=cut

sub is_staged { shift->status_id == $ALLOCATION_STATUS__STAGED; }

=head2 is_picked

Return a true value if the allocation status is B<Picked>.

=cut

sub is_picked { shift->status_id == $ALLOCATION_STATUS__PICKED; }

=head2 is_delivering

Return a true value if the allocation status is B<Delivering>.

=cut

sub is_delivering { shift->status_id == $ALLOCATION_STATUS__DELIVERING; }

=head2 is_prepared

Return a true values if the allocation startus is B<Preparing>

=cut

sub is_prepared { shift->status_id == $ALLOCATION_STATUS__PREPARED; }

=head2 is_delivered

Return a true value if the allocation status is B<Delivered>.

=cut

sub is_delivered { shift->status_id == $ALLOCATION_STATUS__DELIVERED; }

=head2 pick( $msg_factory, $operator_id )

Pick an allocation.

=cut

sub pick {
    my ( $self, $msg_factory, $operator_id ) = @_;

    NAP::XT::Exception::Allocation::Unpickable->throw({
        allocation => $self,
    }) unless $self->is_allocated();

    my $allocation_items = $self->search_related('allocation_items', {
        status_id => $ALLOCATION_ITEM_STATUS__ALLOCATED
    });

    # We could maybe be strict here (i.e. croak) if we are given an
    # allocation with no allocated items. But for now we'll just log
    # and do nothing if we try to pick it, because we know there are
    # a couple of scenarios at least that cause it, and the safest
    # place to deal with it is here. (See DCA-2521, DCA-2523)
    unless ($allocation_items->count) {
        xt_logger()->info(
            "No allocated items for allocation ".$self->id." so pick message not sent"
        );
        return $self;
    }

    # Update the status of the allocation and allocation items
    $self->result_source->schema->txn_do(sub{
        $self->update_status($ALLOCATION_STATUS__PICKING, $operator_id);
        # Make sure we do the select before the update, or the rs will return
        # an empty list the second time around
        $_ ->set_selected($operator_id)
            for $allocation_items->related_resultset('shipment_item')->all;

        $_->update_status($ALLOCATION_ITEM_STATUS__PICKING, $operator_id)
            for ($allocation_items->all());

        # Update time when we send first pick msg for allocation
        $self->update( {pick_sent => \'now()'} ) unless $self->pick_sent;

        # Set flag on shipment to show that picking has started
        $self->shipment->update( {is_picking_commenced => 1} );

        # Send a Pick message
        $msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::PRL::Pick',
            { allocation_id => $self->id }
        );
    });

    xt_logger('PickScheduling')->debug("Sent pick for allocation ".$self->id);

    return $self;
}

=head2 distinct_container_ids

Returns a list of container ids excluding nulls for items in this allocation.

=cut

sub distinct_container_ids { shift->allocation_items->distinct_container_ids; }

=head2 related_containers() : @container_rows | $container_rs

Return resultset with distinct Containers this Allocation's items are
picked into.

=cut

sub related_containers {
    my $self = shift;
    return $self->allocation_items->distinct_containers();
}

=head2 update_status

The allocation item log table needs multiple entries (one for each allocation_item)
if the allocation status changes, so this does an efficient batch insert.

=cut

sub update_status {
    my ($self, $new_status, $operator_id) = @_;

    $self->update({ status_id => $new_status });

    my $log_entries = [];

    foreach my $ai ($self->allocation_items) {
        $ai->discard_changes;
        push(@$log_entries, {
            operator_id               => $operator_id,
            allocation_status_id      => $new_status,
            allocation_item_id        => $ai->id,
            allocation_item_status_id => $ai->status->id
        });
    }

    $self->result_source->schema->resultset('Public::AllocationItemLog')->populate($log_entries);
    return $self;
}

=head2 cancel_allocation_items() -> $self

Cancel the allocation items on the allocation (we cannot really cancel an allocation).

=cut

sub cancel_allocation_items {
    my $self = shift;

    return $self unless $self->is_allocated;

    $self->result_source->schema->txn_do(
        sub {
            my @allocation_items
                = grep { $_->is_allocated } $self->allocation_items;

            for my $allocation_item (@allocation_items) {
                $allocation_item->update_status(
                    $ALLOCATION_ITEM_STATUS__CANCELLED,
                    $APPLICATION_OPERATOR_ID,
                );
            }

            $self->send_allocate_message( $self->msg_factory );
        }
    );

    return $self;
}

sub send_allocate_message {
    my ($self, $message_factory) = @_;
    return XTracker::AllocateManager->send_allocate_message(
        $self,
        $message_factory,
    );
}

=head2 mark_as_delivered( $message_data, $operator_id )

Mark an allocation as delivered. To be called on receipt of the
deliver_response message.

=cut

sub mark_as_delivered {
    my ($self, $message_data, $operator_id) = @_;

    NAP::XT::Exception::Allocation::CannotMarkAsDelivered->throw({
        allocation => $self,
    }) unless $self->is_delivering();

    $self->update_status($ALLOCATION_STATUS__DELIVERED, $operator_id);

    if ($message_data->{item_details}) {
        foreach my $item (@{$message_data->{item_details}}) {

            my $allocation_item = $self->undelivered_picked_item_by_sku($item->{sku});
            next unless ($allocation_item);

            $allocation_item->update({
                delivered_at   => $item->{delivered_at},
                delivery_order => \"nextval('allocation_item_delivery_order_seq')",
            });

            my $prl_delivery_destination = $self->result_source->schema->resultset(
                'Public::PrlDeliveryDestination'
            )->search({
                message_name => $item->{destination},
            })->first;
            unless ($prl_delivery_destination) {
                xt_logger->error(sprintf(
                    "Couldn't find prl_delivery_destination to match [%s] for sku [%s] in allocation [%s]",
                    $item->{destination}, $item->{sku}, $self->id
                ));
                next;
            }
            unless ($prl_delivery_destination->id == ($self->prl_delivery_destination_id//0)) {
                xt_logger->error(sprintf(
                    "Actual prl_delivery_destination [%s] doesn't match allocation's requested destination [%s] for sku [%s] in allocation [%s]",
                    $item->{destination},
                    (
                        $self->prl_delivery_destination ?
                        $self->prl_delivery_destination->message_name :
                        'NONE',
                    ),
                    $item->{sku}, $self->id
                ));
            }
            $allocation_item->update({
                actual_prl_delivery_destination_id => $prl_delivery_destination->id,
            });
        }
    ### ? If we haven't seen all the allocation_items we were expecting
    #### ? Log error
    }


}

=head2 undelivered_picked_item_by_sku( $sku ) : $allocation_item_row | undef

Find an allocation item from this allocation that matches the sku provided,
hasn't been delivered yet, but has been picked.

(Note that the search_by_sku method on shipment item takes care of looking
for vouchers or normal products, so we don't need to worry about that here.)

=cut

sub undelivered_picked_item_by_sku {
    my ($self, $sku) = @_;

    my $allocation_item = $self->shipment->shipment_items
    ->search_by_sku($sku)
    ->search_related('allocation_items', {})
    ->search({
        delivered_at => undef,
        status_id    => $ALLOCATION_ITEM_STATUS__PICKED
    },{
        order_by => 'id',
    })
    ->first;

    unless ($allocation_item) {
        xt_logger->error(sprintf(
            "No undelivered picked allocation_item for allocation [%s] matching sku [%s]",
            $self->id, $sku
        ));
    }

    return $allocation_item;
}

=head2 get_prl_delivery_destination( ) : $prl_destination_row | undef

Returns the prl_delivery_destination row that represents the correct
destination for this allocation.

Returns C<undef> for PRLs that don't have the concept of a destination.

N.B. Currently hard-coded to the GOH lanes. Whenever we have another PRL
that supports integration, we'll need to make this more generic.

=cut

sub get_prl_delivery_destination {
    my $self = shift;

    # Return undef for PRLs that don't have delivery destinations
    if (! $self->prl->has_delivery_destinations) {
        return undef;
    }

    if ($self->prl->id == $PRL__GOH) {
        # Direct lane is a good first guess.
        my $destination_id = $PRL_DELIVERY_DESTINATION__GOH_DIRECT;
        foreach my $sibling ($self->siblings->filter_not_picked) {
            if ($self->prl->integrates_with_prl($sibling->prl)) {
                $destination_id = $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION;
                last;
            }
        }
        my $destination = $self->prl->prl_delivery_destinations->find({
            id => $destination_id,
        });
        return $destination;
    } else {
        # Shouldn't ever get here
        return undef;
    }
}

=head2 send_prepare_message : undef

=cut

sub send_prepare_message {
    my ($self, $message_factory) = @_;

    $message_factory //= $self->msg_factory;

    $self->update_status(
        $ALLOCATION_STATUS__PREPARING,
        $APPLICATION_OPERATOR_ID,
    );

    $message_factory->transform_and_send(
        "XT::DC::Messaging::Producer::PRL::Prepare",
        { allocation => $self },
    );

    return;
}

=head2 mark_as_prepared : undef

Change the allocation's status to 'prepared'

=cut

sub mark_as_prepared {
    my $self = shift;

    $self->update_status(
        $ALLOCATION_STATUS__PREPARED,
        $APPLICATION_OPERATOR_ID,
    );

    return;
}

=head2 send_deliver_message

=cut

sub send_deliver_message {
    my ($self, $message_factory) = @_;

    $message_factory //= $self->msg_factory;

    $self->update_status(
        $ALLOCATION_STATUS__DELIVERING,
        $APPLICATION_OPERATOR_ID,
    );
    $message_factory->transform_and_send(
        "XT::DC::Messaging::Producer::PRL::Deliver",
        { allocation => $self },
    );

    return;
}

=head2 has_siblings : 0|1

Are there other allocations in this shipment?

=cut

sub has_siblings {
    my $self = shift;

    return !! $self->siblings->count;
}

=head2 siblings : @sibling_allocations | $sibling_allocations_rs

In list context, returns a list of allocations that are in the same shipment
as this one.

In scalar context, returns a resultset containing the same set of allocations.

=cut

sub siblings {
    my $self = shift;
    $self->shipment->allocations->excluding_id($self->id);
}

=head2 integration_containers : @integration_container_rows | $integration_row_rs

In list context, returns a list of integration containers associated with
this allocation.

In scalar context returns a resultset object containing the same set of
integration containers.

=cut

sub integration_containers {
    my $self = shift;

    my $schema = $self->result_source->schema;
    my $integration_container_rs =
        $schema->resultset('Public::IntegrationContainer');

    return $integration_container_rs->search({
        container_id => { in => [ $self->distinct_container_ids ] },
    });
}

=head2 routed_integration_containers : @integration_container_rows | $integration_row_rs

In list context, returns a list of integration containers associated with
this allocation that have been routed to integration but haven't arrived.

In scalar context returns a resultset object containing the same set of
integration containers.

=cut

sub routed_integration_containers {
    my $self = shift;

    return $self->integration_containers->search({
         is_complete => 0,
        routed_at   => { '!=', undef },
        arrived_at  => undef,
    });
}

=head2 integration_containers_expected : $integer

Returns the number of integration containers that are associated with this
allocation and are currently en route to integration.

=cut

sub integration_containers_expected {
    my $self = shift;

    return $self->routed_integration_containers->count;
}

=head2 siblings_from_prl : @allocations|$allocation_rs

In list context, returns a list of sibling allocations from a given PRL.

In scalar context returns a result set containing the same set of allocations.

=cut

sub siblings_from_prl {
    my ($self, $prl_id) = @_;

    return $self->siblings->search({
        prl_id => $prl_id,
    });
}

=head2 dcd_siblings : @allocations|$allocation_rs

In list context, returns a list of sibling allocations from the DCD PRL.

In scalar context, returns a result set containing the same set of allocations.

=cut

sub dcd_siblings {
    my $self = shift;

    return $self->siblings_from_prl($PRL__DEMATIC);
}

=head2 unpicked_dcd_siblings : @allocations

In list context, returns a list of unpicked sibling allocations from the
DCD PRL.

In scalar context, returns a result set containing the same set of allocations.

=cut

sub unpicked_dcd_siblings {
    my $self = shift;
    return $self->dcd_siblings->filter_not_picked;
}

=head2

Reduce unpicked dcd sibling to those
without all their items cancelled.

=cut

sub pickable_dcd_siblings {
    my $self = shift;
    my @unpicked = $self->unpicked_dcd_siblings->search(undef, {
        prefetch => [ 'allocation_items' ]
    });

    @unpicked = grep {
        $_->allocation_items->pickable_count > 0
    } @unpicked;

    return @unpicked;
}

=head2 goh_siblings : @allocations|$allocation_rs

In list context, returns a list of sibling allocations from the GOH PRL.

In scalar context, returns a result set containing the same set of allocations.

=cut

sub goh_siblings {
    my $self = shift;

    return $self->siblings_from_prl($PRL__GOH);
}

=head2 unpicked_goh_siblings : @allocations

In list context, returns a list of unpicked sibling allocations from the
GOH PRL.

In scalar context, returns a result set containing the same set of allocations.

=cut

sub unpicked_goh_siblings {
    my $self = shift;

    return $self->goh_siblings->filter_not_picked;
}

=head2 maybe_send_deliver_from_prepare_response

Called from the prepare_response handler. Works out whether we need to send
a deliver message.

=cut

sub maybe_send_deliver_from_prepare_response {
    my $self = shift;

    if ($self->has_siblings) {
        # We'll want to send deliver later if there are integration containers
        # on the way, or there are no integration containers on the way, but
        # there are still unpicked DCD allocations.
        #
        # So we only send deliver if there are no unpicked DCD allocations and
        # also no integration containers expected.
        my @dcd_sibling_containers_expected = map {$_->routed_integration_containers->all} $self->dcd_siblings;
        my @pickable_dcd_siblings = $self->pickable_dcd_siblings;

        if (!@pickable_dcd_siblings &&
            !@dcd_sibling_containers_expected) {
            $self->send_deliver_message;
        }
    } else {
        # For the 1 GOH item scenario, we just immediately send the
        # deliver message
        $self->send_deliver_message;
    }
}

=head2 maybe_send_deliver_from_pick_complete

Called from the pick_complete handler. Works out whether we need to send
a deliver message.

=cut

sub maybe_send_deliver_from_pick_complete {
    my $self = shift;

    # If this is a DCD allocation
    return unless $self->prl->id == $PRL__DEMATIC;
    # AND we're expecting a GOH allocation which is prepared
    my @prepared_goh_siblings = grep { $_->is_prepared } $self->goh_siblings;
    return unless @prepared_goh_siblings;
    # AND no more integration containers expected
    return if $self->integration_containers_expected;
    # THEN send deliver for GOH allocation(s)
    foreach my $goh_sibling (@prepared_goh_siblings) {
        $goh_sibling->send_deliver_message;
    }
}

=head single_item_shipment : 0|1

Is this allocation a single item shipment?

=cut

sub is_single_item_shipment {
    my $self = shift;

    # Can't be a single item shipment if we have more than
    # one allocation item.
    return 0 if $self->allocation_items->count > 1;

    # Can't be a single item shipment if there are more
    # allocations in the shipment
    return 0 if $self->has_siblings;

    return 1;
}

=head2 sibling_allocations : $allocation_rs

Return resultset of other allocations belonging to the same shipment.

=cut

sub sibling_allocations {
    my $self = shift;
    return $self->shipment->allocations->exclude_allocation_by_id($self->id);
}

=head2 create_integration_container($container_id, $integration_prl) : $integration_container | die

Create an integration container and populate it with the items from this
allocation that are in the container.

Return the integration_container row that was created, or die on error.

=cut

sub create_integration_container {
    my ($self, $container_id, $integration_prl_row) = validated_list(\@_,
        container_id    => { isa => 'Str'},
        integration_prl => { isa => 'XTracker::Schema::Result::Public::Prl'},
    );
    my $schema = $self->result_source->schema;

    # Create an integration_container row to record the fact we've sent it
    # to integration.
    my $integration_container_row = $schema->resultset('Public::IntegrationContainer')->create({
        'container_id' => $container_id,
        'prl_id'       => $integration_prl_row->id,
        'from_prl_id'  => $self->prl_id,
        'routed_at'    => $schema->db_now(),
    });

    # Populate the integration container with the items we already know are in it.
    foreach my $allocation_item_row ($self->allocation_items) {
        if ($allocation_item_row->picked_into//'' eq $container_id) {
            $integration_container_row->create_related('integration_container_items', {
                status_id          => $INTEGRATION_CONTAINER_ITEM_STATUS__PICKED,
                allocation_item_id => $allocation_item_row->id,
            });
        }
    }

    return $integration_container_row;
}


=head2 prl_for_integration : $prl_row | undef

Return the prl this allocation can be integrated with if there is one
for this allocation.

Requires that this allocation is ready for integration, and has another
allocation to integrate with.

To be used when we get a container_ready and need to decide whether to
send it to packing or integration.

=cut

sub prl_for_integration {
    my $self = shift;

    my $prl = $self->prl;

    # Does this prl integrate with any others?
    my @prls_to_integrate_with = $prl->integrates_with->all;
    return unless (scalar @prls_to_integrate_with);

    # Is the allocation fully picked? If not, we should have a less-full
    # container later on with the final item(s), so it would be better to
    # send that one to integration instead.
    # Note: this does mean that partly-short-picked allocations won't ever
    # go to integration, but that's a rare enough case that we don't mind.
    return if $self->unpicked_items->count;

    # Does the allocation in this container belong to the same shipment
    # as an allocation in the correct status in a prl this one integrates
    # with?
    foreach my $prl_to_integrate_with (@prls_to_integrate_with) {
        my $sibling_allocations_for_integration = $self
            ->sibling_allocations
            ->filter_in_prl($prl_to_integrate_with->name)
            ->filter_ready_for_integration;
        return $prl_to_integrate_with if $sibling_allocations_for_integration->count;
    }

    return;
}

=head2 has_triggering_items : boolean

Return true if this allocation has items in a state that could trigger a pick
in another prl later. Return false if it doesn't.

=cut

sub has_triggering_items {
    my $self = shift;

    # If it still has active items, it could trigger a pick later
    return 1 if $self->allocation_items->filter_active->count;

    # If this allocation is staged or still in picking with all items
    # picked, it won't have any active items but it could trigger a pick
    # after it's inducted, but only if it does contain at least one picked
    # item (i.e. it's not completely short/cancelled)
    return 1 if (
        ($self->is_staged || $self->is_picking)
        && $self->allocation_items->filter_picked->count
    );

    return 0;
}

1;
