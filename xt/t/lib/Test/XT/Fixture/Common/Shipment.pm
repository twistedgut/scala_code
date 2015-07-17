package Test::XT::Fixture::Common::Shipment;
use NAP::policy "tt", "class";
with (
    "Test::Role::WithSchema",
    "NAP::Test::Class::PRLMQ",
    "Test::XT::Fixture::Role::WithProduct",
);

=head1 NAME

Test::XT::Fixture::Common::Shipment - Common Shipment fixture setup

=head1 DESCRIPTION

Test fixture with a Shipment that can be picked.

Feel free to add more transformations here.

=cut

use Carp qw/ confess /;
use List::MoreUtils qw/ any /;

use Test::More;

use Test::XTracker::Data;
use Test::XTracker::Data::Order;

use XT::Domain::PRLs;
use XTracker::Constants::FromDB qw(
    :allocation_item_status
    :allocation_status
    :shipment_status
    :shipment_item_status
    :shipment_hold_reason
    :cancel_reason
    :prl
    :pws_action
    :container_status
    :shipment_item_returnable_state
);
use XTracker::Constants qw/ $APPLICATION_OPERATOR_ID /;
use vars qw/$PRL__DEMATIC $PRL__FULL/;


=head1 ATTRIBUTES

=cut

# Attributes from Fixture::Common::Product

# Overriden with a sensible default in sub classes
has flow => (
    is       => "ro",
    required => 1,
);

# If set, hard code allocations to this PRL
has prl_id => (
    is => "ro",
);

has order_row => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $order_info = $self->flow->new_order(
            products => $self->pids,
            $self->prl_id ? ( prl_id => $self->prl_id ) :(),
        );
        return $order_info->{order_object};
    },
);

has shipment_row => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->order_row->shipments->first;
    },
);


has picked_container_id => (
    is      => "rw",
    trigger => sub { shift->clear_picked_container_row },
);

has picked_container_row => (
    is      => "rw",
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->schema->find( Container => $self->picked_container_id );
    },
    clearer => "clear_picked_container_row",
);

has additional_container_rows => (
    is => "ro",
    lazy => 1,
    default => sub {
        my $self = shift;
        return [
            map { $self->rs("Container")->find($_) }
            Test::XT::Data::Container->create_new_containers({ how_many => 2 })
        ],
    }
);



=head1 METHODS

=cut

sub BUILD {
    my $self = shift;
    note "*** BEGIN Shipment Fixture setup " . ref($self);

    $self->shipment_row;

    note "*** Shipment ID " . $self->shipment_row->id;
    note "*** END Shipment Fixture setup " . ref($self);
}

sub discard_changes { }

# Don't override, add an "after" modifier to discard more things
after discard_changes => sub {
    my $self = shift;

    for my $attribute ("shipment_row", "picked_container_row") {
        my $attribute_row = $self->$attribute or next;
        $attribute_row->discard_changes;
    }

    ( $_ and $_->discard_changes ) for (
        @{$self->additional_container_rows},
        $self->shipment_row->shipment_items,
    );

    if( my $picked_container_row = $self->picked_container_row ) {
        if(my $allocation_row = $picked_container_row->allocation_row) {
            $allocation_row->discard_changes();
        }
    }

    return $self;
};

sub with_normal_sla {
    my $self = shift;
    $self->shipment_row->update({ sla_cutoff => \"NOW() + '1 day'::interval" });
    return $self;
}

sub with_urgent_sla {
    my $self = shift;
    $self->shipment_row->update({ sla_cutoff => \"NOW() - '1 day'::interval" });
    return $self;
}

sub with_allocated_shipment {
    my $self = shift;

    # This is usually redundant, the allocation has probably already
    # been made earlier, during order/shipment creation
    Test::XTracker::Data::Order->allocate_shipment(
        $self->shipment_row,
    );

    return $self;
}

sub with_selected_shipment {
    my $self = shift;

    $self->with_allocated_shipment();
    Test::XTracker::Data::Order->select_shipment( $self->shipment_row );

    return $self;
}

sub with_selected_shipment_item {
    my ($self, $shipment_item_row) = @_;

    $self->with_allocated_shipment();
    Test::XTracker::Data::Order->select_shipment_item( $shipment_item_row );

    return $self;
}

sub with_allocating_pack_space_shipment {
    my $self = shift;

    $self->with_selected_shipment();
    Test::XTracker::Data::Order->allocating_pack_space_for_shipment( $self->shipment_row );

    return $self;
}

sub with_allocated_product {
    my $self = shift;

    my $shipment_item_row = $self->shipment_row
        ->shipment_items->filter_prls_without_staging_area()->first;

    Test::XTracker::Data::Order->allocate_shipment_and_allocation_item(
        $shipment_item_row,
    );

    return $self;
}

sub with_staged_shipment {
    my $self = shift;
    $self->with_selected_shipment();
    my @container_ids = Test::XTracker::Data::Order->stage_shipment(
        $self->shipment_row,
    );
    # TODO: Support multiple containers here if the shipment has more than
    # one allocation to stage
    $self->picked_container_id($container_ids[0]);

    return $self;
}

# Restore shipment and allocation to non-picked, selected status
sub with_restaged_shipment {
    my $self = shift;

    # Set the status back to what it needs to be for
    # with_staged_shipment to work
    $self->shipment_row->shipment_items->search_related(
        "allocation_items",
    )->search_related(
        "allocation",
    )->update({
        status_id => $ALLOCATION_STATUS__STAGED,
    });

    if(my $container_row = $self->picked_container_row) {
        $container_row->update({
            has_arrived => undef,
            arrived_at  => undef,
        });
    }

    # $self->with_staged_shipment();

    return $self;
}

sub with_picked_shipment {
    my $self = shift;

    # A Shipment (really an Allocation) can go to Picked either directly
    # from Selected, or via Staged. In this case we select it, then pick
    # it to avoid that extra step.
    $self->with_selected_shipment();
    my ($container_id) = Test::XTracker::Data::Order->pick_shipment(
        $self->shipment_row,
    );
    $self->picked_container_id($container_id);

    return $self;
}

sub allocation_pick_complete {
    my ($self, $allocation_row) = @_;

    my @container_ids = Test::XTracker::Data::Order->allocation_pick_complete(
        $allocation_row,
    );

    return @container_ids;
}

sub shipment_pick_complete {
    my $self = shift;

    my @container_ids;
    foreach my $allocation_row ($self->shipment_row->allocations) {
        push @container_ids, $self->allocation_pick_complete($allocation_row);
    }

    return \@container_ids;
}

sub with_prepared_goh_allocation {
    my $self = shift;

    unless ($self->can("goh_allocation_row")) {
        note "No goh_allocation_row for this fixture, so can't prepare it - doing nothing";
        return $self;
    }

    $self->goh_allocation_row->allocation_items->update({
        status_id => $ALLOCATION_ITEM_STATUS__PICKED,
    });
    $self->goh_allocation_row->update({
        status_id => $ALLOCATION_STATUS__PREPARED,
    });

    return $self;
}

sub with_delivered_goh_allocation {
    my $self = shift;

    unless ($self->can("goh_allocation_row")) {
        note "No goh_allocation_row for this fixture, so can't deliver it - doing nothing";
        return $self;
    }

    $self->goh_allocation_row->allocation_items->update({
        status_id => $ALLOCATION_ITEM_STATUS__PICKED,
    });
    $self->goh_allocation_row->update({
        status_id => $ALLOCATION_STATUS__DELIVERED,
    });

    return $self;
}

sub with_shipment_item_moved_into {
    my ($self, $shipment_item_row, $container_row) = @_;

    note "Fixture: moving " . $shipment_item_row->id . " into " . $container_row->id;
    if(!$shipment_item_row) {
        confess("No Shipment Item available, do you need to increase the pid_count (currently " . $self->pid_count . ")? E.g. " . ref($self) . "->new({pid_count => 4})")
    }

    $shipment_item_row->update({
        container_id => $container_row->id,
    });
    $shipment_item_row->allocation_items->update({
        picked_into => $container_row->id,
    });

    $container_row->update({
        status_id => $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS,
    });

    return $self;
}

sub with_first_shipment_item_moved_into {
    my ($self, $container_row) = @_;
    return $self->with_shipment_item_moved_into(
        $self->shipment_row->shipment_items->first,
        $container_row,
    );
}

sub with_shipment_items_moved_into_additional_containers {
    my $self = shift;

    my (undef, @shipment_items_rows) =
        grep {
            if(my $allocation_item_row = $_->allocation_items->first) {
                my $allocation_status_id = $allocation_item_row->allocation->status_id;

                any { $_ == $allocation_status_id }
                    ($ALLOCATION_STATUS__STAGED, $ALLOCATION_STATUS__PICKED);
            }
            else { 1 } # If no allocation, assume it's picked
        }
        $self->shipment_row->shipment_items->all;
    for my $container_row ( @{$self->additional_container_rows} ) {
        $self->with_shipment_item_moved_into(
            shift(@shipment_items_rows),
            $container_row,
        );
    }

    return $self;
}

sub with_shipment_on_hold {
    my $self = shift;

    $self->shipment_row->put_on_hold({
        status_id   => $SHIPMENT_STATUS__HOLD,
        operator_id => $APPLICATION_OPERATOR_ID,
        norelease   => 1,
        reason      => $SHIPMENT_HOLD_REASON__INCOMPLETE_PICK,
    });

    return $self;
}

sub with_empty_containers {
    my $self = shift;
    my @container_rows = (
        $self->picked_container_row,
        @{$self->additional_container_rows},
    );
    for my $container_row (@container_rows) {
        $container_row->shipment_items->update({ container_id => undef });
    }

    return $self;
}

sub with_cancelled_shipment {
    my $self = shift;
    my $shipment_row = $self->shipment_row;
    $shipment_row->set_cancelled( $APPLICATION_OPERATOR_ID );
    for my $shipment_item_row ($shipment_row->shipment_items) {
        $self->with_cancelled_shipment_item( $shipment_item_row );
    }
}

sub with_cancelled_shipment_item {
    my ($self, $shipment_item_row) = @_;

    # The stock manager is unimportant, just reuse the previous one
    # (and it's the same channel for all anyway)
    my $stock_manager
          = $self->{_stock_manager}
        ||= $shipment_item_row->shipment->order->channel->stock_manager;

    $shipment_item_row->cancel({
        operator_id             => $APPLICATION_OPERATOR_ID,
        customer_issue_type_id  => $CANCEL_REASON__OTHER,
        pws_action_id           => $PWS_ACTION__CANCELLATION,
        stock_manager           => $stock_manager,
    });

    return $self;
}

sub with_additional_shipment_item {
    my ($self, $pid) = @_;

    $self->shipment_row->create_related(
        shipment_items => {
            variant_id              => $pid->variants->first->id,
            duty                    => 0,
            tax                     => 0,
            unit_price              => 0,
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
            returnable_state_id     => $SHIPMENT_ITEM_RETURNABLE_STATE__YES,
        },
    );
    $self->flow->allocate_to_shipment($self->shipment_row);

    return $self;
}

# Pick into a new container, and set (overwrite if already set)
# ->picked_container_row
sub with_item_picked_into_container {
    my ($self, $container_row, $allocation_row) = @_;

    for my $allocation_item_row ($allocation_row->allocation_items) {
        $self->send_message(
            $self->create_message(
                ItemPicked => {
                    allocation_id => $allocation_row->id,
                    client        => $allocation_item_row->shipment_item->variant->prl_client,
                    pgid          => 'p12345',
                    user          => "Dirk Gently",
                    sku           => $allocation_item_row->shipment_item->variant->sku,
                    container_id  => $container_row->id,
                }
            ),
        );
    }

    return $self;
}

sub with_container_ready {
    my ($self, $allocation_row, $container_row) = @_;

    my $prl_amq_identifier = $allocation_row->prl_amq_identifier;
    $self->send_message(
        $self->create_message(
            ContainerReady => {
                container_id => $container_row->id->as_id,
                allocations  => [
                     { allocation_id => $allocation_row->id },
                ],
                prl          => $prl_amq_identifier,
            },
        ),
    );

    return $self;
}


sub with_pick_complete_for_allocation {
    my ($self, $allocation_row) = @_;

    $allocation_row->pick_complete( $APPLICATION_OPERATOR_ID );

    return $self;
}

sub with_container_inducted {
    my ($self, $container_row) = @_;

    $self->flow->flow_msg__prl__induct_container(
        container_row => $container_row,
    );

    return $self;
}

sub pick_allocation_into_container_and_test {
    my ($self, $which, $allocation_row, $container_row, $test_sub) = @_;

    note "Picking $which into container (" . $container_row->id . ")";

    note "ItemPicked for $which";
    $self->with_item_picked_into_container(
        $container_row,
        $allocation_row,
    );
    $test_sub->();


    note "Container Ready for $which";
    $self->with_container_ready(
        $allocation_row,
        $container_row,
    );
    $test_sub->();


    note "Pick Complete for $which Allocation(" . $allocation_row->id . "), Shipment (" . $allocation_row->shipment_id . ")";
    $self->with_pick_complete_for_allocation( $allocation_row );

    $self->discard_changes();

    return $self;
}

sub with_packed_shipment {
    my $self = shift;

    # Simplification: ignore the box it's packed into
    # See Test::XT::Data::Order->packed_order for details

    for my $shipment_item_row ($self->shipment_row->shipment_items) {
        $shipment_item_row->update({
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED,
        });
    }

    return $self;
}

sub with_dispatched_shipment {
    my $self = shift;

    # Simplification: ignore the box it's packed into
    # See Test::XT::Data::Order->packed_order for details

    $self->shipment_row->update({
        shipment_status_id => $SHIPMENT_STATUS__DISPATCHED,
    });
    for my $shipment_item_row ( $self->shipment_row->shipment_items ) {
        $shipment_item_row->update({
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED,
        });
        $shipment_item_row->create_related(
            shipment_item_status_logs => {
                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED,
                operator_id             => $APPLICATION_OPERATOR_ID,
            },
        );
    }

    return $self;
}
