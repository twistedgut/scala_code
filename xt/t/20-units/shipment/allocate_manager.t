#!/usr/bin/env perl

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
};

use Test::XTracker::RunCondition prl_phase => 'prl';
use XTracker::AllocateManager;
use XTracker::Constants qw/:prl_type/;
use XTracker::Constants::FromDB qw/
    :allocation_item_status
    :allocation_status
    :shipment_hold_reason
    :shipment_item_status
    :storage_type
/;
use XTracker::Config::Local qw/config_var/;
use Test::XT::Data;
use Test::XTracker::Artifacts::RAVNI;
use List::MoreUtils qw/part/;
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

sub startup : Tests() {
    my $self = shift;
    # Test::XT::Data instance
    $self->{'test_xt_data'} = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    );

    # Create a mechanism for sending XT messages
    $self->{'factory'} = Test::XTracker::MessageQueue->new();

    # It has a baroque API, so we're going to fall back on a much more useful
    # way of grabbing messages...
    $self->{'msg_dir'} = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
}

# If we call allocate shipment on a shipment with a picked allocation, we
# should get a new allocation for any items that have been 'unpicked'.
sub allocate_shipment_packing_exception : Tests() {
    my $self = shift;
    my $shipment = $self->flat_item_shipment(2);
    my ($allocation) = $self->allocate_and_receive_messages( $shipment, {
        'Full' => [ $shipment->shipment_items ] } );

    # Set the allocation itself to picked
    $allocation->update_status($ALLOCATION_STATUS__PICKED, $APPLICATION_OPERATOR_ID);
    $_->update_status($ALLOCATION_ITEM_STATUS__PICKED, $APPLICATION_OPERATOR_ID)
        for $allocation->allocation_items;

    my ( $picked_si, $replacement_si ) = $shipment->shipment_items;
    $picked_si->update({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED });

    # Set one of the allocation items
    my ($new_allocation) = $self->allocate_and_receive_messages( $shipment, {
        'Full' => [ $replacement_si ] } );
    isnt( $allocation->id, $new_allocation->id, "New allocation ID");
}

# Once we've started picking, allocations can't be changed. But if someone tries
# to allocate a shipment again, we don't want to generate a new allocation for
# items that are already expected to be coming out... But if we get a new item
# (which can only currently happen due to size change), we need another
# allocation generated for that (while not changing the original one!)
sub allocate_shipment_during_picking : Tests() {
    my $self = shift;
    my $shipment = $self->flat_item_shipment(4);

    my ($allocation) = $self->allocate_and_receive_messages( $shipment, {
        'Full' => [ $shipment->shipment_items ] } );

    # Update the allocation status to be picking
    $allocation->update({ status_id => $ALLOCATION_STATUS__PICKING });

    # Set the allocation item statuses. Two picked, two picking
    my ( $si_picked, $si_picked_cancelled, $si_picking, $si_picking_cancelled )
        = $shipment->shipment_items;
    $_->active_allocation_item->update_status($ALLOCATION_ITEM_STATUS__PICKED, $APPLICATION_OPERATOR_ID) for
        ( $si_picked, $si_picked_cancelled );
    $_->active_allocation_item->update_status($ALLOCATION_ITEM_STATUS__PICKING, $APPLICATION_OPERATOR_ID) for
        ( $si_picking, $si_picking_cancelled );

    # We cancel one of the picked, and one of the picking, at the SI level
    $si_picked_cancelled->update({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING });
    $si_picking_cancelled->update({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING });

    # Add two new items to the shipment
    my @new_items = $self->flat_item_shipment(2)->shipment_items;
    $_->update({shipment_id => $shipment->id}) for @new_items;

    # Some useful SKU-based diagnostics
    note("SKU rundown:");
    note(sprintf("SKU: [%s] SI status: [%s] AI status: [%s]",
            $_->variant->sku,
            $_->shipment_item_status->status,
            ($_->allocation_items->first ? $_->allocation_items->first->status->status :
                "No AI")
        )) for $shipment->shipment_items;

    # A new call to allocate should return a single new allocation with the two
    # new items in it
    my ($new_allocation) = $self->allocate_and_receive_messages( $shipment, {
        'Full' => [ @new_items ] } );
    isnt( $allocation->id, $new_allocation->id, "New allocation ID");
}

# Test `allocate_response`, which is called by the AllocateResponse handler
#
# Check we preferentially flip Requested to Short
# Check we flip all other Requested to Allocated
# Check the order goes on hold
sub allocate_response_short_test : Tests() {
    my $self = shift;

    # Create an order with 200 items of the same SKU, and allocate it
    my ($pid) = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        how_many => 1,
    });
    my $shipment = $self->{'test_xt_data'}->new_order(
        products  => [($pid) x 200],
        no_ensure => 1,
        dont_allocate => 1,
    )->{'shipment_object'};

    # Allocate the shipment
    my ($allocation) = $self->allocate_and_receive_messages( $shipment, {
        'Full' => [ $shipment->shipment_items ] } );

    # Make two of the items Requested, and the rest Allocated
    my @allocation_items = $allocation->allocation_items;
    my $sku = $allocation_items[0]->shipment_item->variant->sku;

    my @allocated_items = @allocation_items;
    my @requested_items = shift( @allocated_items ), shift( @allocated_items );
    $_->update_status($ALLOCATION_ITEM_STATUS__ALLOCATED, $APPLICATION_OPERATOR_ID)
        for @allocated_items;

    $self->item_statuses_count(
        "having manually set allocation item statuses",
        \@allocation_items,
        requested => 2,
        allocated => 198,
        short     => 0,
    );
    is( $shipment->discard_changes->is_on_hold, 0, "Shipment not on hold" );

    # Send an allocate response with two short
    XTracker::AllocateManager->allocate_response({
        allocation => $allocation,
        allocation_items => \@allocation_items,
        sku_data => {
            $sku => { allocated => 198, short => 2 },
        },
        operator_id => $APPLICATION_OPERATOR_ID
    });

    # We should have shorted our two requested items only
    $self->item_statuses_count(
        "after two short",
        \@allocation_items,
        requested => 0,
        short     => 2,
        allocated => 198,
    );
    is( $shipment->discard_changes->is_on_hold, 1, "Shipment on hold" );
    is( $_->status_id, $ALLOCATION_ITEM_STATUS__SHORT,
        "Allocation item short: " . $_->id ) for @requested_items;

    # Check we short one more of the allocated if we send another
    XTracker::AllocateManager->allocate_response({
        allocation => $allocation,
        allocation_items => \@allocation_items,
        sku_data => {
            $sku => { allocated => 197, short => 1 },
        },
        operator_id => $APPLICATION_OPERATOR_ID
    });
    $self->item_statuses_count(
        "after one more short",
        \@allocation_items,
        requested => 0,
        short     => 3,
        allocated => 197,
    );
    is( $shipment->discard_changes->is_on_hold, 1, "Shipment on hold" );

    my $shipment_hold_row = $self->schema->resultset('Public::ShipmentHold')->search({
        shipment_id => $shipment->id,
    },{
        order_by => { -desc=>'id' },
    })->first;
    is( $shipment_hold_row->shipment_hold_reason_id, $SHIPMENT_HOLD_REASON__FAILED_ALLOCATION,
        'Shipment hold reason is "Failed Allocation"' );
    is( $_->status_id, $ALLOCATION_ITEM_STATUS__SHORT,
        "Allocation item short: " . $_->id ) for @requested_items;

}

# Check that if a shipment is already on finance hold and we get a short
# allocate_response, we leave it like that instead of overwriting the
# finance hold with a normal hold.

sub allocate_response_short_finance_hold_test : Tests() {
    my $self = shift;

    # Create an order with one item, put it on finance hold, then allocate it
    my ($pid) = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        how_many => 1,
    });
    my $shipment = $self->{'test_xt_data'}->new_order(
        products  => [$pid],
        no_ensure => 1,
        dont_allocate => 1,
    )->{'shipment_object'};

    $shipment->set_status_finance_hold($APPLICATION_OPERATOR_ID);

    # Allocate the shipment and check we sent the right message
    my ($allocation) = $self->allocate_and_receive_messages( $shipment, {
        'Full' => [ $shipment->shipment_items ] } );

    my @allocation_items = $allocation->allocation_items;
    my $sku = $allocation_items[0]->shipment_item->variant->sku;


    # Send an allocate response with nothing allocated
    XTracker::AllocateManager->allocate_response({
        allocation => $allocation,
        allocation_items => \@allocation_items,
        sku_data => {
            $sku => { allocated => 0, short => 1 },
        },
        operator_id => $APPLICATION_OPERATOR_ID
    });

    is( $_->status_id, $ALLOCATION_ITEM_STATUS__SHORT,
        "Allocation item short: " . $_->id ) for @allocation_items;

    ok( $shipment->discard_changes->is_on_finance_hold, "Shipment still on finance hold" );
}


sub item_statuses_count {
    my ( $self, $msg, $allocation_items, %counts ) = @_;
    my @statuses = part { $_->status_id } @$allocation_items;
    my $returned = {
        requested => scalar( @{ $statuses[$ALLOCATION_ITEM_STATUS__REQUESTED] || [] } ),
        short     => scalar( @{ $statuses[$ALLOCATION_ITEM_STATUS__SHORT] || [] } ),
        allocated => scalar( @{ $statuses[$ALLOCATION_ITEM_STATUS__ALLOCATED] || [] } ),
    };

    is_deeply( $returned, \%counts, "Allocation Item Status Counts match " . $msg)
        || eq_or_diff( $returned, \%counts );
}

sub flat_item_shipment {
    my $self = shift;
    my $how_many = shift;
    # Create an order with two items
    # We're going to insist that they have a storage-type of Flat so that
    # they're headed for the same PRL
    my @flat_pids = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        how_many => $how_many,
    });
    my $shipment = $self->{'test_xt_data'}->new_order(
        products => \@flat_pids,
        dont_allocate => 1,
    )
        ->{'shipment_object'};

    return $shipment;
}

sub missing_storage_type : Tests() {
    my $self = shift;

    my $shipment = $self->flat_item_shipment(1);

    # Make the product have no storage type
    $shipment->shipment_items->first->product->update({
        'storage_type_id' => undef,
    });

    throws_ok (
        sub {
            $shipment->allocate({
                factory => $self->{'factory'}->producer,
                operator_id => $APPLICATION_OPERATOR_ID
            });
        },
        qr/no storage type set for product/,
        'Calling ->allocate throws the correct error'
    );

}

# Run through various allocate shipment tests, first creating a new shipment,
# and then knocking bits off it, looking at the resulting generated messages
# after running allocate_shipment
sub various_allocate_shipment_tests : Tests() {
    my $self = shift;

    my $shipment = $self->flat_item_shipment(2);

    # New shipment
    my @shipment_items = $shipment->shipment_items;

    # We shouldn't have allocation items for either shipment_item
    note("Confirming no allocation items for shipment items");
    is( $_->active_allocation_item, undef,
        sprintf("ID[%s] SKU[%s] has no allocation item", $_->id, $_->variant->sku ) )
            for @shipment_items;

    # Call allocate on it
    note "Calling allocate_shipment() for the first time";
    my ($allocation) = $self->allocate_and_receive_messages( $shipment, {
        'Full' => \@shipment_items,
    } );
    my $original_allocation_id = $allocation->id;
    ok( $original_allocation_id, "Allocation ID exists: " . $original_allocation_id );


    # Both shipment items should now have an allocation item ...
    note("Checking both shipment items gained an allocation item");
    ok(
        $_->active_allocation_item, sprintf(
            "ID[%s] SKU[%s] has an active allocation item",
            $_->id, $_->variant->sku
        )
    ) for @shipment_items;
    # ... and it should be in status 'requested'
    is( $_->active_allocation_item->status->status, 'requested',
        sprintf("ID[%s] SKU[%s] has an allocation item in status 'requested'",
            $_->id, $_->variant->sku )
        )
            for @shipment_items;

    # Add a shipment item via duplicating an old one
    my $new_si;
    {
        my $from = $shipment_items[0];
        my $col_data = { %{$from->{_column_data}} };
        my $colinfo = $from->columns_info([ keys %$col_data ]);
        foreach my $col (keys %$col_data) {
            delete $col_data->{$col}
                if $colinfo->{$col}{is_auto_increment};
        }
        $new_si = $from->result_source->resultset->create( $col_data );
    }

    push( @shipment_items, $new_si );
    note(sprintf("Created new shipment item %d SKU[%s]",
        $new_si->id,
        $new_si->variant->sku,
    ));

    # Rerun it
    note("Checking the new shipment item shows up in allocation");
    ($allocation) = $self->allocate_and_receive_messages( $shipment, {
        'Full' => \@shipment_items,
    } );
    is( $allocation->id, $original_allocation_id, "Correct allocation ID persisted");

    # Close the allocation and allocation items as if they'd been picked
    my $schema = $shipment->result_source->schema;
    my $allocation_obj = $schema->resultset('Public::Allocation')->find(
        $original_allocation_id
    );
    # Marks the allocate as discharged
    $allocation_obj->update({ status_id => $ALLOCATION_STATUS__PICKED });
    $_->update_status($ALLOCATION_ITEM_STATUS__PICKED, $APPLICATION_OPERATOR_ID) for
        map { $_->active_allocation_item } @shipment_items;

    # Rerun it
    note("Having closed the previous allocation, check a new one is created");
    ($allocation) = $self->allocate_and_receive_messages( $shipment, {
        'Full' => \@shipment_items, } );
    my $new_allocation_id = $allocation->id;
    ok( $original_allocation_id != $new_allocation_id, "Allocation ID differs" );

    # Rerunning it shouldn't generate another message
    note("Rerunning the same thing shouldn't generate a new message");
    $self->allocate_and_receive_messages( $shipment, {} );

    # Cancel the first shipment item
    my $si_to_cancel = shift( @shipment_items );
    $si_to_cancel->update({
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED });

    # Should be absent from allocation
    note("Checking cancelled item is absent from allocation");
    ($allocation) = $self->allocate_and_receive_messages( $shipment, {
        'Full' => \@shipment_items, } );
    is( $allocation->id, $new_allocation_id, "New allocation ID persisted");

    # Nuke the final two shipment items, and we should get an empty allocation
    note("Confirm an allocation with all cancelled items is blank");
    $_->update({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING }) for
        @shipment_items;
    ($allocation) = $self->allocate_and_receive_messages( $shipment, {
        'Full' => [], } );
    is( $allocation->id, $new_allocation_id, "New allocation ID persisted");
}

sub allocate_and_receive_messages {
    my ( $self, $shipment, $expected ) = @_;

    # Call allocate_shipment
    my @allocations = $shipment->allocate({
        factory => $self->{'factory'}->producer,
        operator_id => $APPLICATION_OPERATOR_ID
    });

    # Get back a list of all the messages
    my @messages = $self->{'msg_dir'}->new_files;

    # Reasonable count?
    is(
        (scalar @messages),
        (scalar values %$expected),
        "Expected and found the same number of messages: " . (scalar @messages)
    );

    # We should have one - and just one - message per PRL, and that should match
    for my $msg ( @messages ) {
        my $prl = XT::Domain::PRLs::get_prl_from_amq_queue({
            amq_queue => $msg->path,
        });
        my $expected_items = delete $expected->{ $prl->name };
        ok( $expected_items, "Found a message for PRL " . $prl );

        $self->check_message( $msg->{'payload_parsed'}, $expected_items );
    }

    if ( my ($extra) = %$expected ) {
        not_ok( "Didn't find a msg for PRL $extra" );
    }

    return @allocations;
}

sub check_message {
    my ($self, $message, $items) = @_;
    my %expected_items;
    for my $item ( @$items ) {
        $expected_items{ $item->variant->sku } //= {
            quantity => 0,
            client => $item->variant->prl_client,
            return_priority => '',
            sku => $item->variant->sku,
            stock_status => $PRL_TYPE__STOCK_STATUS__MAIN,
        };
        $expected_items{ $item->variant->sku }->{'quantity'}++
    }

    is_deeply( $message->{'item_details'}, [
        sort { $a->{sku} cmp $b->{sku} } (values %expected_items)
    ], "Item details in message are correct" );
}

sub ensure_allocation_items_logged :Tests() {
    my $self = shift;
    my $schema = Test::XTracker::Data->get_schema;

    my $ALLOC_COUNT = 4;

    my $log_rs = $schema->resultset('Public::AllocationItemLog');
    $log_rs->delete;

    # create a new order
    my ($pid) = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT
    });

    my $shipment = $self->{'test_xt_data'}->new_order(
        products => [($pid) x $ALLOC_COUNT]
    )->{'shipment_object'};

    # check each shipment item mentioned in allocation item log
    # as having been requested
    my ($allocation) = $schema->resultset('Public::Allocation')->search({
        shipment_id => $shipment->id
    });

    my @allocation_items = $schema->resultset('Public::AllocationItem')->search({
        allocation_id => $allocation->id
    })->all;

    note("ALLOCATION ITEMS: ". join(', ', map { $_->id } @allocation_items) . " FOR ". $allocation->id . "\n");

    my @allocation_items_ids = map { $_->id } @allocation_items;
    my $count = $log_rs->search({
        'allocation_item_id' => { '-in' => \@allocation_items_ids },
        'allocation_item_status_id' => $ALLOCATION_ITEM_STATUS__REQUESTED,
        'allocation_status_id' => $ALLOCATION_STATUS__REQUESTED
    })->count;

    is($count, $ALLOC_COUNT, "$ALLOC_COUNT allocation items logged with correct request status");
    $log_rs->delete;

    my $sku = $allocation_items[0]->shipment_item->variant->sku;

    XTracker::AllocateManager->allocate_response({
        allocation => $allocation,
        allocation_items => \@allocation_items,
        sku_data => {
            $sku => { allocated => $ALLOC_COUNT - 1, short => 1 },
        },
        operator_id => $APPLICATION_OPERATOR_ID
    });

    $count = $log_rs->search({
        'allocation_item_id'        => { '-in' => \@allocation_items_ids },
        'allocation_item_status_id' => $ALLOCATION_ITEM_STATUS__ALLOCATED,
        'allocation_status_id'      => $ALLOCATION_STATUS__ALLOCATED
    })->count;

    is($count, $ALLOC_COUNT, "All the allocation items were logged as allocated");

    $count = $log_rs->search({
        'allocation_item_id' => { '-in' => \@allocation_items_ids },
        'allocation_item_status_id' => $ALLOCATION_ITEM_STATUS__SHORT
    })->count;

    is($count, 1, "1 of the allocation items is also logged as a short pick");

    # this test is for logging items.
    # various_allocate_shipment_tests that messages produced by allocating items
    # are produced as expected, so we can safely ignore them here.
    my @messages = $self->{'msg_dir'}->new_files;
}

Test::Class->runtests;
