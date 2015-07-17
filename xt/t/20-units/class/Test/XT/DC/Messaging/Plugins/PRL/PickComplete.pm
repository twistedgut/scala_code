package Test::XT::DC::Messaging::Plugins::PRL::PickComplete;

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
};
use Test::XTracker::RunCondition
    prl_phase => 'prl',
    export => [ qw( $prl_rollout_phase ) ];

=head1 NAME

Test::XT::DC::Messaging::Plugins::PRL::PickComplete

=head1 DESCRIPTION

Unit tests for XT::DC::Messaging::Plugins::PRL::PickComplete

=cut

use XT::DC::Messaging::Plugins::PRL::ContainerReady;
use Test::XT::Data;
use Test::XTracker::Data;
use Test::XT::Data::Container;
use XTracker::Constants::FromDB qw/
    :allocation_item_status
    :allocation_status
    :shipment_item_status
    :storage_type
/;
use XTracker::AllocateManager;
use Test::XTracker::LocationMigration;

sub startup : Tests() {
    my $self = shift;
    # Test::XT::Data instance
    $self->{'test_xt_data'} = Test::XT::Data->new_with_traits(
        traits  => [ qw/Test::XT::Data::Order Test::Role::DBSamples/ ]
    );
}

sub happy_path : Tests() {
    my $self = shift;

    my %tests = (
        Full => {
            shipment            => $self->flat_item_shipment( 2 ),
            post_picking_status => $ALLOCATION_STATUS__STAGED,
        },
        DCD  => {
            shipment            => $self->dematic_flat_item_shipment( 2 ),
            post_picking_status => $ALLOCATION_STATUS__PICKED,
        },
    );

    if ($prl_rollout_phase >=2) {
        $tests{GOH} = {
            shipment            => $self->hanging_item_shipment( 2 ),
            post_picking_status => $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE,
        };
    };

    foreach my $test (keys %tests) {
        note "Happy path testing: $test PRL";

        my $shipment = $tests{$test}->{shipment};
        my $container_id = $self->pick_allocation_items(
            map { $_->allocation_items } $shipment->allocations
        );

        my ($allocation) = $shipment->allocations;

        # PickComplete here should:
        #   - Change the Allocation to Picked
        #   - Not add any shipment notes
        #   - Not put the shipment on hold

        is( $allocation->discard_changes->status_id, $ALLOCATION_STATUS__PICKING,
            "Pre-PickComplete, allocation status is PICKING");
        is( $shipment->is_on_hold, 0, "Pre-PickComplete, shipment is not on hold");

        $self->send_pick_complete( $shipment );

        is( $allocation->discard_changes->status_id,
            $tests{$test}->{post_picking_status},
            'Post-PickComplete, allocation status is correct' );
        is( $shipment->is_on_hold, 0,
            "Post-PickComplete, shipment is not on hold");
    }
}

sub short_pick : Tests() {
    my $self = shift;
    my $shipment = $self->flat_item_shipment( 4 );
    my ($allocation) = $shipment->allocations;
    note "Shipment " . $shipment->id;
    note 'PRL is: ' . $allocation->prl->name;

    # Pick just two of the allocation items
    my ( @allocation_items_short, @allocation_items_normal );
    ( @allocation_items_short[0,1], @allocation_items_normal )
        = $allocation->allocation_items;
    my $container_id = $self->pick_allocation_items(
        @allocation_items_normal,
    );

    # Get the shipment items associated with the allocation items, and pretend
    # two of them were cancelled during picking - one that will be picked and one
    # that will be short.
    my ($shipment_item_cancel, $shipment_item_short, $shipment_item_picked, $shipment_item_picked_cancelled) = (
        $allocation_items_short[0]->shipment_item,
        $allocation_items_short[1]->shipment_item,
        map {$_->shipment_item} @allocation_items_normal
    );
    $shipment_item_cancel->update({
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
    });
    $shipment_item_picked_cancelled->update({
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
    });


    # PickComplete here should:
    #   - Change the Allocation to Picked
    #   - Change the two PICKING items to short
    #   - Add a shipment note saying they're missing
    #   - Update the unpicked shipment item that wasn't cancelled to NEW
    #   - Update the cancelled short shipment item to CANCELLED
    #   - Leave the status of the picked shipment items (cancelled and not cancelled) alone
    #   - Put the shipment on hold

    # Check the status before pick_complete

    # Allocation status
    is( $allocation->discard_changes->status_id, $ALLOCATION_STATUS__PICKING,
        "Pre-PickComplete, allocation status is PICKING");
    # Shipment hold
    is( $shipment->is_on_hold, 0, "Pre-PickComplete, shipment is not on hold");

    # PICKING allocation items
    $self->assert_allocation_items_status(
        \@allocation_items_short, $ALLOCATION_ITEM_STATUS__PICKING,
        "Pre-PickComplete, item to be shorted"
    );
    # PICKED allocation items
    $self->assert_allocation_items_status(
        \@allocation_items_normal, $ALLOCATION_ITEM_STATUS__PICKED,
        "Pre-PickComplete, item to be successfully picked"
    );
    # CANCEL PENDING shipment item
    $self->assert_shipment_items_status(
        [$shipment_item_cancel],
        $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
        "Pre-PickComplete, cancelled shipment item"
    );
    # SELECTED shipment item
    $self->assert_shipment_items_status(
        [$shipment_item_short],
        $SHIPMENT_ITEM_STATUS__SELECTED,
        "Pre-PickComplete, unpicked shipment item"
    );
    # PICKED shipment item
    $self->assert_shipment_items_status(
        [$shipment_item_picked],
        $SHIPMENT_ITEM_STATUS__PICKED,
        "Pre-PickComplete, picked shipment item"
    );
    # CANCEL PENDING shipment item
    $self->assert_shipment_items_status(
        [$shipment_item_picked_cancelled],
        $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
        "Pre-PickComplete, picked cancelled shipment item"
    );

    # Perform the pick_complete
    $self->send_pick_complete( $shipment );

    # Check the status after pick_complete

    # Allocation status
    is( $allocation->discard_changes->status_id, $ALLOCATION_STATUS__STAGED,
        "Post-PickComplete, allocation status is staged");
    # Shipment hold
    is( $shipment->discard_changes->is_on_hold, 1, "Post-PickComplete, shipment is on hold");
    # PICKING->SHORT allocation items
    $self->assert_allocation_items_status(
        \@allocation_items_short, $ALLOCATION_ITEM_STATUS__SHORT,
        "Post-PickComplete, shorted item"
    );
    # PICKED allocation items
    $self->assert_allocation_items_status(
        \@allocation_items_normal, $ALLOCATION_ITEM_STATUS__PICKED,
        "Post-PickComplete, item picked"
    );
    # CANCEL PENDING shipment item - should now be CANCELLED
    $self->assert_shipment_items_status(
        [$shipment_item_cancel],
        $SHIPMENT_ITEM_STATUS__CANCELLED,
        "Post-PickComplete, cancelled shipment item"
    );
    # SELECTED shipment item - this is the only shipment item status that should've changed
    $self->assert_shipment_items_status(
        [$shipment_item_short],
        $SHIPMENT_ITEM_STATUS__NEW,
        "Post-PickComplete, unpicked shipment item"
    );
    # PICKED shipment item
    $self->assert_shipment_items_status(
        [$shipment_item_picked],
        $SHIPMENT_ITEM_STATUS__PICKED,
        "Post-PickComplete, picked shipment item"
    );
    # CANCEL PENDING shipment item
    $self->assert_shipment_items_status(
        [$shipment_item_picked_cancelled],
        $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
        "Post-PickComplete, picked cancelled shipment item"
    );

    # Check the message
    my ($shipment_note) = $shipment->shipment_notes;
    like( $shipment_note->note,
        qr/PRL \[Full\] short-picked the following for allocation/,
        "A sensible shipment note has appeared"
    );
}

sub assert_allocation_items_status {
    my ( $self, $allocation_items, $status_id, $description ) = @_;

    for my $allocation_item ( @$allocation_items ) {
        $allocation_item->discard_changes();

        is( $allocation_item->status_id, $status_id,
            sprintf( "%s (ID: %d SKU: %s) is in status %d",
                $description, $allocation_item->id,
                $allocation_item->shipment_item->variant->sku, $status_id
            )
        );
    }
}

sub assert_shipment_items_status {
    my ( $self, $shipment_items, $status_id, $description ) = @_;

    for my $shipment_item ( @$shipment_items ) {
        $shipment_item->discard_changes();

        is( $shipment_item->shipment_item_status_id, $status_id,
            sprintf( "%s (Shipment item ID: %d SKU: %s) is in status %d",
                $description, $shipment_item->id,
                $shipment_item->variant->sku, $status_id
            )
        );
    }
}

sub flat_item_shipment {
    my $self = shift;
    my $how_many = shift;
    # Create an order with $how_many items
    # We're going to insist that they have a storage-type of Flat so that
    # they're headed for the same PRL
    return $self->shipment_for_storage_type(
        $PRODUCT_STORAGE_TYPE__FLAT, $how_many,
    );
}

sub dematic_flat_item_shipment {
    my $self = shift;
    my $how_many = shift;

    return $self->shipment_for_storage_type(
        $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT, $how_many,
    );
}

sub hanging_item_shipment {
    my $self = shift;
    my $how_many = shift;

    return $self->shipment_for_storage_type(
        $PRODUCT_STORAGE_TYPE__HANGING, $how_many,
    );
}

# TODO: Support for multi-PRL shipments
sub shipment_for_storage_type {
    my ($self, $storage_type, $how_many) = @_;

    $storage_type //= $PRODUCT_STORAGE_TYPE__FLAT;
    $how_many     //= 1;

    my @pids = Test::XTracker::Data->create_test_products({
        storage_type_id => $storage_type,
        how_many => $how_many,
    });
    my $shipment = $self->{'test_xt_data'}->selected_order(
        products => \@pids,
    )->{'shipment_object'};

    return $shipment;
}

# Picks a set of allocation items in to a new container, sending appropriate
# ItemPicked and ContainerReady messages, and returning a $container_id
sub pick_allocation_items {
    my ( $self, @allocation_items ) = @_;

    my $container_id = Test::XT::Data::Container->get_unique_id();

    # Item picked messages
    $self->send_message( $self->create_message(
        ItemPicked => {
            allocation_id => $_->allocation->id,
            client        => $_->shipment_item->variant->prl_client,
            pgid          => 'p12345',
            user          => "Dirk Gently",
            sku           => $_->shipment_item->variant->sku,
            container_id  => $container_id,
        }
    ) ) for @allocation_items;

    # Send a container ready
    my %allocations = map { $_->id => 1 } map { $_->allocation } @allocation_items;
    $self->send_message( $self->create_message(
        ContainerReady => {
            container_id => $container_id,
            allocations  => [ { allocation_id => $_ } ],
            prl          => "Full",
        }
    )) for keys %allocations;

    return $container_id;
}

# Given a shipment, sends PickComplete for each of its allocations
sub send_pick_complete {
    my ( $self, $shipment ) = @_;
    $self->send_message( $self->create_message(
        PickComplete => { allocation_id => $_->id }
    ) ) for $shipment->allocations;
}

=head2 test_sample_short_pick

Create a sample shipment that has begun picking and send it a pick complete
message B<without> sending it item_picked and container_ready messages.

Then check that:

=over

=item * shipment is cancelled

=item * shipment item is cancelled

=item * allocation is staged (as we created a 'full' PRL allocation)

=item * allocation item is short

=item * stock transfer is cancelled

=cut

sub test_sample_short_pick : Tests {
    my $self = shift;

    # Create a shipment that is in picking
    my $shipment = $self->{'test_xt_data'}->db__samples__create_shipment({
        shipment      => { is_picking_commenced => 1 },
        shipment_item => { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED, },
    });

    my $allocation = $shipment->allocations->single;
    $allocation->update({status_id => $ALLOCATION_STATUS__PICKING});

    my $allocation_item = $allocation->allocation_items->single;

    $self->send_pick_complete($shipment);

    ok(
        $shipment->discard_changes->is_cancelled,
        sprintf( q{shipment %i should be 'Cancelled'}, $shipment->id )
    ) or diag sprintf q{... but it's '%s'}, $shipment->shipment_status->status;

    my $shipment_item = $shipment->shipment_items->single;
    ok(
        $shipment_item->is_cancelled,
        sprintf( q{shipment item %i should be 'Cancelled'}, $shipment_item->id )
    ) or diag sprintf q{... but it's '%s'}, $shipment_item->shipment_item_status->status;

    # The expected allocation status actually depends on what PRL we're in, but
    # as we default to creating 'full' allocations let's just hard-code that we
    # expect 'staged'
    ok(
        $allocation->discard_changes->is_staged,
        sprintf( q{allocation %i should be 'Staged'}, $allocation->id )
    ) or diag sprintf q{... but it's '%s'}, $allocation->status->status;

    ok(
        $allocation_item->discard_changes->is_short_picked,
        sprintf( q{allocation item %i should be 'Short'}, $allocation_item->id )
    ) or diag sprintf q{... but it's '%s'}, $allocation_item->status->status;

    my $stock_transfer = $shipment->stock_transfer;
    ok(
        $stock_transfer->is_cancelled,
        sprintf( q{stock transfer %i should be 'Cancelled'}, $stock_transfer->id )
    ) or diag sprintf q{... but it's '%s'}, $stock_transfer->status->status;
}
