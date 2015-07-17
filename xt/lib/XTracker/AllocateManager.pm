package XTracker::AllocateManager;

=head1 NAME

XTracker::AllocateManager - Handles sending allocation messages for shipments

=head1 DESCRIPTION

Routines for sending and dealing with allocation messages for
shipments (PRL-specific)

=cut

use NAP::policy "tt";
use MooseX::Params::Validate;
use List::MoreUtils qw/part/;
use XTracker::Constants qw/ $APPLICATION_OPERATOR_ID /;
use XTracker::Constants::FromDB qw/
    :allocation_item_status
    :shipment_item_status
    :shipment_status
    :shipment_hold_reason
    :allocation_status
    :customer_issue_type
/;
use XTracker::Database::Shipment qw/insert_shipment_note/;
use Moose::Util::TypeConstraints 'duck_type';
use XTracker::Logfile 'xt_logger';
use XTracker::EmailFunctions;

=head1 METHODS

=cut

# These are our state transition implementations
my %actions = (
    # allocate_shipment transitions accept a shipment item, and return a list
    # or allocation objects for which we need to send messages

    # New allocation item (and perhaps allocation)
    'create requested' => sub {
        my ($shipment_item, $operator_id) = @_;
        my $schema = $shipment_item->result_source->schema;

        unless ($shipment_item->product->storage_type) {
            die "Shipment cannot be allocated as there is no storage type set for product id ".$shipment_item->product->id.". Please contact Distribution Management to look into this and update the product accordingly.\n";
        }

        # Which PRL are we expecting to fulfil this from?
        my $prl = $shipment_item->product->storage_type->main_stock_prl;

        return $schema->txn_do(
            sub {
                # Find or create the relevant allocation
                my $allocation = $shipment_item->shipment
                    ->find_or_create_allocation_to_add_item_for_prl( $prl );

                # Create an allocation item for this shipment item
                my $allocation_item = $schema->resultset('Public::AllocationItem')->create({
                    status_id => $ALLOCATION_ITEM_STATUS__REQUESTED,
                    shipment_item_id => $shipment_item->id,
                    allocation_id => $allocation->id,
                });

                $allocation_item->discard_changes;
                $allocation_item->log_status($operator_id);

                return $allocation;
            }
        );
    },

    # Remove an already requested or allocated item from an allocation
    'set to cancelled' => sub {
        my ($shipment_item, $operator_id) = @_;
        my $allocation_item = $shipment_item->active_allocation_item;

        $allocation_item->update_status(
            $ALLOCATION_ITEM_STATUS__CANCELLED,
            $operator_id,
        );

        return ($allocation_item->allocation);
    },

    # No-op
    'no action' => sub { return; },
);

# This is a list of which transition we use for each state
my %allocate_shipment_transitions = (
    # keys: Shipment Item Status
    'New or Selected' => {
        # keys: Allocation Item Status

        # Essentially, short, cancelled, or picked on a finished
        # allocation
        "Doesn't Exist" => $actions{'create requested'},

        # Every other status that could be active...
        picking         => $actions{'no action'},
        picked          => $actions{'no action'},
        requested       => $actions{'no action'},
        allocated       => $actions{'no action'}, # WHS: Could have reallocated here
    },

    'Cancelled or Cancel Pending' => {
        # keys: Allocation Item Status

        "Doesn't Exist" => $actions{'no action'},
        short           => $actions{'no action'},
        cancelled       => $actions{'no action'},
        picking         => $actions{'no action'},
        picked          => $actions{'no action'},
        requested       => $actions{'set to cancelled'},
        allocated       => $actions{'set to cancelled'},
    }
);

=head2 allocate_shipment($shipment_row, $amq_producer) : @allocation_messages

=cut

sub allocate_shipment {
    my $class = shift;
    my ( $shipment, $factory, $operator_id ) = validated_list(
        \@_,
        shipment    => { isa => 'XTracker::Schema::Result::Public::Shipment'},
        factory     => { isa => duck_type(['transform_and_send']) },
        operator_id => { isa => 'Int' }
    );
    # List of dirty allocation ids - those for which we will need to send a new
    # allocation message
    my @dirty = ();

    # Loop over all shipment items.
    my @shipment_items = $shipment->shipment_items->search({}, {
        prefetch => { allocation_items => ['status','allocation'] }
    });

    xt_logger->trace("There are ".scalar(@shipment_items)." shipment_items for shipment ".$shipment->id);
    for my $si ( @shipment_items ) {
        next if $si->is_virtual_voucher;

        # We are looking for transitions that need to be performed. Transitions
        # are references by Shipment Item status and Allocation Item status,
        # which we'll determine, and use to look up the correct transition in
        # allocate_shipment_transitions, and then use to choose an action from
        # actions.
        #
        # We'll only be looking at AllocationItems that are active - essentially
        # that we still think map to the shipment item. This means that we treat
        # an AI that's 'picked' but belongs to an Allocation that's still in
        # picking as 'active'.

#        $si->discard_changes;
        xt_logger->trace("Shipment item ".$si->id." status ID = ".$si->shipment_item_status_id);
        # Lookup on shipment item status
        my $shipment_item_status = {
            $SHIPMENT_ITEM_STATUS__NEW            => 'New or Selected',
            $SHIPMENT_ITEM_STATUS__SELECTED       => 'New or Selected',
            $SHIPMENT_ITEM_STATUS__CANCELLED      => 'Cancelled or Cancel Pending',
            $SHIPMENT_ITEM_STATUS__CANCEL_PENDING => 'Cancelled or Cancel Pending',
        }->{ $si->shipment_item_status_id } || next;
        xt_logger->trace("Shipment item other type of status = ".$shipment_item_status);

        # We are trying to find an 'active' allocation item, or a picked one for
        # which we have an inprogress allocation.
        my @allocation_items = $si->allocation_items;
        # First try a really active one
        my ( $active_allocation_item ) = grep { ! $_->status->is_end_state }
            @allocation_items;
        # Next, try an active-enough one:
        unless ( $active_allocation_item ) {
            # Picked items
            my @picked_allocation_items =
                grep { $_->status_id eq $ALLOCATION_ITEM_STATUS__PICKED }
                @allocation_items;
            # In picking allocations
            my @active_enough_items =
                grep { $_->allocation->status_id eq $ALLOCATION_STATUS__PICKING }
                @picked_allocation_items;
            # There can only be one, by design
            ( $active_allocation_item ) = @active_enough_items;
        }

        my $allocation_item_status = $active_allocation_item ?
            $active_allocation_item->status->status :
            "Doesn't Exist";
        xt_logger->trace("Allocation item status = $allocation_item_status");

        # Combine those to get an action
        my $action =
            $allocate_shipment_transitions{ $shipment_item_status }
                ->{ $allocation_item_status } or
            # Useful error message if we somehow didn't find something
            die sprintf("Undefined transition for SI Status [%s] AI Status [%s]",
                $shipment_item_status,
                $allocation_item_status );

        # Execute the action, which will return a list of allocation ids that
        # have been changed (or possibly created)
        push( @dirty, $action->( $si, $operator_id ) );
    }

    # Get the unique allocation objects from %allocations. We actually want the
    # last one in each case, as earlier ones may have old data in them. Damn.
    my %allocations;
    $allocations{ $_->id } //= $_ for reverse @dirty;

    # Send the allocation message for each allocation, and return the number we
    # did
    return map {
        my $allocation = $_;
        # doesn't need to log
        ###DCA-2525: if the crap below still isn't fixed, fix it now
        ###TODO: replace this with a call to ->send_allocate_message
        # the only reason to not do this now is to not touch the code
        # here at all at this point
        $allocation->update({ status_id => $ALLOCATION_STATUS__REQUESTED });
        xt_logger->trace("Sending Allocate message");
        $factory->transform_and_send( 'XT::DC::Messaging::Producer::PRL::Allocate', $_ );
        $_;
    } values %allocations;
}

=head2 send_allocate_message($allocation_row, $message_factory) :

Send a PRL::Allocate message for $allocation_row using
$message_factory and set the new status to REQUESTED.

=cut

sub send_allocate_message {
    my ($class, $allocation_row, $message_factory) = @_;

    $allocation_row->update({ status_id => $ALLOCATION_STATUS__REQUESTED });
    $message_factory->transform_and_send(
        "XT::DC::Messaging::Producer::PRL::Allocate",
        $allocation_row,
    );

    return;
}

=head2 allocate_response

Takes a hashref of C<allocation_items>, which is an arrayref of AllocationItem
rows, and C<sku_data>, which is a hashref of the form:

 1234567-123 => { allocated => 5, short => 2 }

Return value is unspecified.

=cut

sub allocate_response {
    my $class = shift;
    my %args = validated_hash(
        \@_,
        allocation => { isa => 'XTracker::Schema::Result::Public::Allocation' },
        allocation_items => { isa =>
            'ArrayRef[XTracker::Schema::Result::Public::AllocationItem]'},
        sku_data => { isa => 'HashRef[HashRef]' },
        operator_id => { isa => 'Int' }
    );
    xt_logger->trace("Processing AllocateResponse");

    # Update the Allocation status
    $args{'allocation'}->update_status($ALLOCATION_STATUS__ALLOCATED, $args{'operator_id'});

    # Split in to Requested and Allocated, and in a format with the useful
    # pieces exposed
    my @allocation_items_by_status = part { $_->{'status'} } map {
        { sku => $_->variant_or_voucher_variant->sku, status => $_->status_id, row => $_ }
    } @{$args{'allocation_items'}};

    my @allocated_ai = @{ $allocation_items_by_status[ $ALLOCATION_ITEM_STATUS__ALLOCATED ] || [] };
    my @requested_ai = @{ $allocation_items_by_status[ $ALLOCATION_ITEM_STATUS__REQUESTED ] || [] };

    # Split the items by SKU, in to lists that are first requested and then
    # allocated.
    my %allocation_items_by_sku;
    for my $item ( @requested_ai, @allocated_ai ) {
        my ( $sku, $value ) = @$item{qw/sku row/};
        $allocation_items_by_sku{ $sku } //= [];
        push( @{$allocation_items_by_sku{ $sku }}, $value );
    }

    # Work through each SKU in the response. For each SKU, in the previous step
    # we created a list of allocation_items, ordered by requested, then
    # allocated. We will step through that in order, flipping items to `short`,
    # and then making sure the remainder is `allocated`. This means that we
    # preferentially short items that are in the `requested` state.
    for my $sku ( keys %{ $args{'sku_data'} } ) {
        my @allocation_items_for_sku = @{$allocation_items_by_sku{ $sku }};

        my $short = $args{ 'sku_data' }->{ $sku }->{ 'short' } || 0;

        # Short out any items we need to
        for (1 .. $short) {
            # Remove the item we'll short from the work list
            my $ai = shift( @allocation_items_for_sku );
            # Flip its status to short
            $ai->update_status($ALLOCATION_ITEM_STATUS__SHORT, $args{'operator_id'});

        }

        # Flip the rest to allocated if they're requested
        foreach my $ai (@allocation_items_for_sku) {
            next if ($ai->status_id != $ALLOCATION_ITEM_STATUS__REQUESTED);
            $ai->update_status($ALLOCATION_ITEM_STATUS__ALLOCATED, $args{'operator_id'});
        }
    }

    # If anything was short, add a note to the shipment about what was short,
    # and place it on hold.
    my $short_details =
        join ";\n",
        # Produce a string from the data
        map {
            sprintf("%d unit%s of SKU %s (%d requested)",
                $_->{'short'},
                (( $_->{'short'} == 1 ) ? '' : 's'),
                $_->{'sku'},
                $_->{'short'} + $_->{'allocated'},
            )
        # Turn the hashkey in to sku, and add to the values
        } map {
            { sku => $_, %{ $args{'sku_data'}->{ $_ } } }
        # All SKUs that are short
        } grep {
            $args{'sku_data'}->{$_}->{'short'} > 0
        # All SKUs in the allocation
        } keys %{ $args{'sku_data'} };

    # Place shipment on hold
    if ( $short_details ) {
        my $allocation = $args{'allocation'};
        my $shipment = $allocation->shipment;

        if ($shipment->is_sample_shipment()) {

            # If this is a sample shipment, just cancel it

            # We don't update the website as whilst for customer shipments they
            # go to return hold and later get cancelled, which increments the
            # pws stock by 1, here we do the cancellation directly, so we don't
            # need to update the pws
            $shipment->cancel(
                operator_id                 => $APPLICATION_OPERATOR_ID,
                customer_issue_type_id      => $CUSTOMER_ISSUE_TYPE__8__STOCK_DISCREPANCY,
                do_pws_update               => 0,
            );
        } else {

            # Pad out the short msg a little
            my $short_msg = sprintf(
                "PRL [%s] cannot allocate the following:\n\n%s",
                $allocation->prl->name(),
                $short_details,
            );

            # Hold the shipment, if we can
            if ( $shipment->can_be_put_on_hold && ! $shipment->is_on_hold ) {
                $shipment->put_on_hold({
                    status_id => $SHIPMENT_STATUS__HOLD,
                    reason => $SHIPMENT_HOLD_REASON__FAILED_ALLOCATION,
                    operator_id => $args{'operator_id'},
                    norelease => 1, # Don't set an automatic release date
                    # This doesn't actually set a message?!
                    comment => $short_msg,
                });
                # Create the shipment note
                insert_shipment_note(
                    $shipment->result_source->schema->storage->dbh,
                    $shipment->id,
                    $APPLICATION_OPERATOR_ID,
                    $short_msg,
                );
            }
            # If the shipment is already on hold, then we don't need to worry -
            # we will resend an allocation message when the shipment comes off hold
            # anyway, which will retrigger this, assuming the operator hasn't
            # done all the cancellations they need to at that point.
        }
    }

}

1;
