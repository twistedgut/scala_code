package Test::XTracker::Schema::Result::Public::ShipmentItem;
use NAP::policy "tt", qw/test class/;

BEGIN {
    extends 'NAP::Test::Class';
    with $_ for qw{Test::Role::WithSchema Test::Role::DBSamples};
};

use MooseX::Params::Validate 'validated_list';

use Test::MockModule;
use Test::MockObject::Extends;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XT::Data;

use XTracker::Constants ':application';
use XTracker::Constants::FromDB qw<
    :allocation_item_status
    :customer_issue_type
    :flow_status
    :packing_exception_action
    :pre_order_item_status
    :pws_action
    :reservation_status
    :return_item_status
    :return_status
    :return_type
    :shipment_class
    :shipment_item_status
    :shipment_status
    :shipment_item_returnable_state
    :container_status
>;
use XTracker::Database::Return;
use Test::XT::Data::Container;
use Test::XT::Fixture::Fulfilment::Shipment;

sub startup : Test(startup => 2) {
    my ( $self ) = @_;

    isa_ok($self->{schema} = Test::XTracker::Data->get_schema, 'XTracker::Schema');

    isa_ok($self->{rs} = $self->{schema}->resultset('Public::ShipmentItem'),
        'XTracker::Schema::ResultSet::Public::ShipmentItem' );

    $self->{data}   = Test::XT::Data->new_with_traits(
        traits  => [
            'Test::XT::Data::Order',
        ],
    );
}

sub test_found : Tests {
    my ( $self ) = @_;

    my ( $schema, $pc_rs ) = @{$self}{qw/schema rs/};

    my $channel = Test::XTracker::Data->any_channel;
    my $variant = (Test::XTracker::Data->grab_products({
        channel_id => $channel->id,
        force_create => 1,
    }))[1][0]->{variant};

    my @shipments = map { $self->db__samples__create_shipment({
        channel_id    => $channel->id,
        variant_id    => $variant->id,
        shipment      => { shipment_status_id => $SHIPMENT_STATUS__LOST },
        shipment_item => { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__LOST },
    }) } 1..2;

    my $statuses = [
        $FLOW_STATUS__CREATIVE__STOCK_STATUS,
        $FLOW_STATUS__SAMPLE__STOCK_STATUS,
        $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
    ];
    # Let's retrieve just sample locations that aren't "special" (i.e. exclude
    # the ones that start with a digit)
    my $location_rs = $schema->resultset('Public::Location')
        ->search(
            {
                'location_allowed_statuses.status_id' => $statuses,
                'me.location' => { q{~} => '^\D', q{!=} => 'IWS' },
            },
            { join => 'location_allowed_statuses' }
        );

    # We need to double-check that none of our locations allow more than one
    # allowed status, or the application won't be able to determine what status
    # the newly found item needs to be in
    if ( my @locations = grep {
        $_->location_allowed_statuses->count != 1
    } $location_rs->all ) {
        die sprintf 'Sample location%s %s do not have one allowed status',
            (@locations == 1 ? q{} : q{s}), join q{, }, map { $_->location } @locations;
    }
    # Get one sample and one non-sample shipment class for testing
    my @classes = (
        sort { ( $a->is_sample()  ) <=> ( $b->is_sample() ) }
            $schema->resultset('Public::ShipmentClass')->all
        )[-1, 0]; # sample, non-sample

    my $test_quantity = sub {
        my %args = @_;
        my ( $si, $location, $expected_quantity ) = @args{qw/shipment_item location expected_quantity/};

        # get quantities for specified variant and location
        my @quantities = $location->search_related('quantities', { variant_id => $si->variant_id })->all;
        # ...there should be just one
        is( scalar @quantities, 1,
            sprintf 'should have one quantity row for variant_id %d at location %s',
            $si->variant_id, $location->location );

        # get the quantity row for this variant and location
        my $quantity = shift @quantities;
        # ...and check the quantity is what's expected
        is( $quantity->quantity, $expected_quantity,
            sprintf 'quantity for variant_id %d at location %s should be %d',
            $si->variant_id, $location->location, $expected_quantity );

        # get the only allowed stock status for this location
        my $expected_status = $location->location_allowed_statuses->related_resultset('status')->single;
        # ...and check the quantity row status matches the location's only allowed stock status
        is( $quantity->status_id, $expected_status->id,
            sprintf 'quantity status for variant_id %d at location %s should be %s',
            $si->variant_id, $location->location, $expected_status->name );

        # check that 'found' correctly restores previous state
        {
            # check that shipment item is not marked lost from a location
            is( $si->lost_at_location_id, undef,
                sprintf 'lost_at_location_id should be null for shipment item %d', $si->id );
            # check that shipment status is 'dispatched'
            my $shipment = $si->shipment;
            is( $shipment->shipment_status_id, $SHIPMENT_STATUS__DISPATCHED,
                sprintf q{shipment %d should be 'Dispatched'}, $shipment->id );
            # if we have a return, we need to check that we have set the statuses correctly
            if ( my $return = $shipment->returns->single ) {
                is( $si->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                    sprintf q{shipment item %d should be 'Return Pending'}, $si->id );
                is( $return->return_status_id, $RETURN_STATUS__AWAITING_RETURN,
                    q{return status should be 'Awaiting Return'} );
                is( $return->return_items->single->return_item_status_id,
                    $RETURN_ITEM_STATUS__AWAITING_RETURN,
                    q{return item status should be 'Awaiting Return'} );
                ok( $return->search_related('return_status_logs',
                    { return_status_id => $RETURN_STATUS__AWAITING_RETURN })
                    ->single,
                    q{return status for 'Awaiting Return' has been logged} );
            }
            # check that shipment item status is 'dispatched'
            else {
                is( $si->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__DISPATCHED,
                    sprintf q{shipment item %d should be 'Dispatched'}, $si->id );
            }
        }
    };

    # TODO: Test transfer pending return
    for my $location ( $location_rs->all ) {
        my $expected_quantity = 0;

        for my $class ( @classes ) {
            # We do this with two shipments so we can test both cases - where
            # we create a new quantity and where we update the existing one
            for my $shipment ( @shipments ) {
                my $si = $shipment->shipment_items->single;
                # Here we test outgoing/returning lost sample shipments
                # which are at transfer pending - when they are being
                # returned we need them to reset to our 'lost' state
                # TODO: Check if it's better that we 'lose' shipments for real... (i.e. ->lose_shipment/->lose_item)
                for my $with_return ( 0, grep { $_->location eq 'Transfer Pending' } $location ) {
                    if ( $with_return ) {
                        my $return = $shipment->create_related('returns', {
                            rma_number => XTracker::Database::Return::generate_RMA($schema->storage->dbh, $shipment->id),
                            return_status_id => $RETURN_STATUS__LOST,
                        });
                        my $return_item = $return->create_related('return_items', {
                            shipment_item_id => $si->id,
                            return_item_status_id => $RETURN_ITEM_STATUS__AWAITING_RETURN,
                            customer_issue_type_id => $CUSTOMER_ISSUE_TYPE__7__JUST_UNSUITABLE,
                            return_type_id => $RETURN_TYPE__RETURN,
                            variant_id => $variant->id,
                        });
                    }
                    else {
                        $si->delete_related('return_items');
                        $shipment->returns->related_resultset('return_status_logs')->delete;
                        $shipment->delete_related('returns');
                    }
                    $si->update({ lost_at_location_id => $location->id });
                    $shipment->update({ shipment_class_id => $class->id });

                    # We should die if we attempt to find a non-sample shipment
                    unless ( $shipment->is_sample_shipment ) {
                        throws_ok( sub { $si->found( $APPLICATION_OPERATOR_ID ) },
                            qr{only implemented for sample},
                            sprintf( q{should die when we don't have a sample shipment class (%s) - (%s)},
                                $class->class, $location->location )
                        );
                        next;
                    }
                    # Mark the shipment item found
                    $si->found($APPLICATION_OPERATOR_ID);
                    # Check quantity rows updated correctly by ->found()
                    $test_quantity->(
                        shipment_item => $si,
                        location      => $location,
                        expected_quantity => ++$expected_quantity,
                    );
                }
            }
        }
    }
}

=head2 test_get_reservation_to_link_to

Tests the 'get_reservation_to_link_to' method to make sure it picks the correct reservation.

=cut

sub test_get_reservation_to_link_to : Tests() {
    my $self    = shift;

    my $channel     = Test::XTracker::Data->any_channel;
    my $order_details = $self->{data}->new_order(
        products    => 3,
        channel     => $channel,
    );
    my $customer    = $order_details->{customer_object};
    my $shipment    = $order_details->{shipment_object};
    my @ship_items  = $shipment->shipment_items->all;

    # create normal reservations for all but the last Shipment Item
    my $last_ship_item = pop @ship_items;
    my @reservations;
    foreach my $item ( @ship_items ) {
        push @reservations, _create_reservation( $customer, $item );
    }

    # create a Reservation with a Pre-Order for the last Shipment Item
    push @reservations, _create_reservation( $customer, $last_ship_item, { for_pre_order => 1 } );


    note "check Reservation with the correct Statuses only get chosen";

    # get all Statuses
    my $statuses    = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::ReservationStatus', {
        allow   => [ $RESERVATION_STATUS__UPLOADED ],
    } );

    note "NOT Allowed";
    foreach my $status ( @{ $statuses->{not_allowed} } ) {
        $reservations[0]->update( { status_id => $status->id } );
        my $got = $ship_items[0]->get_reservation_to_link_to;
        ok( !defined $got, "No Reservation was Found with Status: '" . $status->status . "'" );
    }

    note "ALLOWED";
    foreach my $status ( @{ $statuses->{allowed} } ) {
        $reservations[0]->update( { status_id => $status->id } );
        my $got = $ship_items[0]->get_reservation_to_link_to;
        isa_ok( $got, 'XTracker::Schema::Result::Public::Reservation', "Found a Reservation with Status: '" . $status->status . "'" );
        cmp_ok( $got->id, '==', $reservations[0]->id, "and the Reservation is the expected one" );
        my $link    = $ship_items[0]->link_with_reservation( $got );
        isa_ok( $link, 'XTracker::Schema::Result::Public::LinkShipmentItemReservation',
                    "call to 'link_with_reservation' returned a link record" );
        cmp_ok( $link->reservation_id, '==', $reservations[0]->id, "and linked to the expected Reservation" );
        $self->_delete_link_shipment_item_to_reservation($ship_items[0]);     # get rid of it for future tests
    }


    note "test when a Shipment has the SAME Shipment Items still finds different Reservations after 'Purchased'";
    # update the second Shipment Item & Reservation
    # to be for the same variant as for the first
    $ship_items[1]->update( { variant_id => $ship_items[0]->variant_id } );
    $reservations[1]->update( { variant_id => $ship_items[0]->variant_id, ordering_id => ( $reservations[0]->ordering_id + 1 ) } );

    my $got = $ship_items[1]->get_reservation_to_link_to;
    cmp_ok( $got->id, '==', $reservations[0]->id, "First Reservation found" );
    $got->set_purchased;                                # Set the Reservation as Purchased
    $ship_items[1]->link_with_reservation( $got );      # and then link it to the Shipment Item

    # now try again and it should return 'undef'
    $got    = $ship_items[1]->get_reservation_to_link_to;
    ok( !defined $got, "after linking, subsequent call to 'get_reservation_to_link_to' returns 'undef'" );

    $got    = $ship_items[0]->get_reservation_to_link_to;
    cmp_ok( $got->id, '==', $reservations[1]->id, "Second Reservation found" );
    $got->set_purchased;                                # Set the Reservation as Purchased
    $ship_items[0]->link_with_reservation( $got );      # and then link it to the Shipment Item

    # now try again and it should return 'undef'
    $got    = $ship_items[0]->get_reservation_to_link_to;
    ok( !defined $got, "after linking, subsequent call to 'get_reservation_to_link_to' returns 'undef'" );


    note "test that a Reservation for the Customer & Variant BUT for a Pre-Order is NOT linked too";
    $got    = $last_ship_item->get_reservation_to_link_to;
    ok( !defined $got, "NO Reservation found if the only one available is for a Pre-Order" );

    # create a normal Reservation that should get linked too
    my $reservation = _create_reservation( $customer, $last_ship_item );
    $got    = $last_ship_item->get_reservation_to_link_to;
    cmp_ok( $got->id, '==', $reservation->id, "but DOES find a Normal Reservation when one is available" );
}

=head2 get_preorder_reservation_to_link_to

Tests the 'get_preorder_reservation_to_link_to' method to make sure it picks the correct reservation.

=cut

sub test_get_preorder_reservation_to_link_to : Tests() {
    my $self    = shift;

    my $channel     = Test::XTracker::Data->any_channel;
    my $order       = Test::XTracker::Data::PreOrder->create_order_linked_to_pre_order( {
        channel     => $channel,
        how_many    => 3,
    } );
    my $customer    = $order->customer;
    my $shipment    = $order->get_standard_class_shipment;
    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'variant_id' } )->all;
    my $pre_order   = $order->get_preorder;
    my @pre_items   = $pre_order->pre_order_items->search( {}, { order_by => 'variant_id' } )->all;

    # get reservations for all the Shipment Items
    my @reservations;
    foreach my $item ( @ship_items ) {
        my $reservation = $item->link_shipment_item__reservations->first->reservation;

        # delete links and set Reservation back to 'Uploaded'
        $item->link_shipment_item__reservations->delete;
        $reservation->update( { status_id => $RESERVATION_STATUS__UPLOADED } );

        push @reservations, $reservation;
    }

    # create a Reservation without a Pre-Order for the last Shipment Item
    my $last_ship_item  = $ship_items[-1];
    $reservations[-1]   = _create_reservation( $customer, $last_ship_item );


    note "check Pre-Order Item with the correct Statuses only get chosen";

    # get all Statuses
    my $statuses    = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::PreOrderItemStatus', {
        allow   => [ $PRE_ORDER_ITEM_STATUS__EXPORTED ],
    } );

    note "NOT Allowed";
    foreach my $status ( @{ $statuses->{not_allowed} } ) {
        $pre_items[0]->update( { pre_order_item_status_id => $status->id } );
        my $got = $ship_items[0]->get_preorder_reservation_to_link_to;
        ok( !defined $got, "No Reservation was Found with Status: '" . $status->status . "'" );
    }

    note "ALLOWED";
    foreach my $status ( @{ $statuses->{allowed} } ) {
        $pre_items[0]->update( { pre_order_item_status_id => $status->id } );
        my $got = $ship_items[0]->get_preorder_reservation_to_link_to;
        isa_ok( $got, 'XTracker::Schema::Result::Public::Reservation', "Found a Reservation with Status: '" . $status->status . "'" );
        cmp_ok( $got->id, '==', $reservations[0]->id, "and the Reservation is the expected one" );
    }


    note "check Reservation with the correct Statuses only get chosen";

    # get all Statuses
    $statuses   = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::ReservationStatus', {
        allow   => [ $RESERVATION_STATUS__UPLOADED ],
    } );

    note "Test : Reservation NOT Allowed status";
    foreach my $status ( @{ $statuses->{not_allowed} } ) {
        $reservations[0]->update( { status_id => $status->id } );
        my $got = $ship_items[0]->get_preorder_reservation_to_link_to;
        ok( !defined $got, "No Reservation was Found with Status: '" . $status->status . "'" );
    }

    note "Test: Reservation ALLOWED status";
    foreach my $status ( @{ $statuses->{allowed} } ) {
        $reservations[0]->update( { status_id => $status->id } );
        my $got = $ship_items[0]->get_preorder_reservation_to_link_to;
        isa_ok( $got, 'XTracker::Schema::Result::Public::Reservation', "Found a Reservation with Status: '" . $status->status . "'" );
        cmp_ok( $got->id, '==', $reservations[0]->id, "and the Reservation is the expected one" );
        my $link    = $ship_items[0]->link_with_reservation( $got );
        isa_ok( $link, 'XTracker::Schema::Result::Public::LinkShipmentItemReservation',
                    "call to 'link_with_reservation' returned a link record" );
        cmp_ok( $link->reservation_id, '==', $reservations[0]->id, "and linked to the expected Reservation" );
        $self->_delete_link_shipment_item_to_reservation($ship_items[0]); # get rid of it for future tests
    }


    note "test when a Shipment has the SAME Shipment Items still finds different Reservations after 'Purchased'";
    # update the second Shipment Item & Reservation
    # to be for the same variant as for the first
    $ship_items[1]->update( { variant_id => $ship_items[0]->variant_id } );
    $pre_items[1]->update( { variant_id => $ship_items[0]->variant_id } );
    $reservations[1]->update( { variant_id => $ship_items[0]->variant_id } );

    my $got = $ship_items[1]->get_preorder_reservation_to_link_to;
    cmp_ok( $got->id, '==', $reservations[0]->id, "First Reservation found" );
    $got->set_purchased;                                # Set the Reservation as Purchased
    $ship_items[1]->link_with_reservation( $got );      # and then link it to the Shipment Item

    # now try again and it should return 'undef'
    $got    = $ship_items[1]->get_preorder_reservation_to_link_to;
    ok( !defined $got, "after linking, subsequent call to 'get_reservation_to_link_to' returns 'undef'" );

    $got    = $ship_items[0]->get_preorder_reservation_to_link_to;
    cmp_ok( $got->id, '==', $reservations[1]->id, "Second Reservation found" );
    $got->set_purchased;                                # Set the Reservation as Purchased
    $ship_items[0]->link_with_reservation( $got );      # and then link it to the Shipment Item

    # now try again and it should return 'undef'
    $got    = $ship_items[0]->get_preorder_reservation_to_link_to;
    ok( !defined $got, "after linking, subsequent call to 'get_reservation_to_link_to' returns 'undef'" );


    note "test that a Reservation for the Customer & Variant BUT NOT for a Pre-Order is NOT linked too";
    $got    = $last_ship_item->get_preorder_reservation_to_link_to;
    ok( !defined $got, "NO Reservation found if the only one available is NOT for a Pre-Order" );
}

=head2 test_is_returnable_on_pws

Tests the method 'is_returnable_on_pws' which returns TRUE or FALSE based
on the 'returnable_state_id' field.

=cut

sub test_is_returnable_on_pws : Tests() {
    my $self    = shift;

    my $order_details = $self->{data}->new_order(
        products    => 1,
        channel     => Test::XTracker::Data->any_channel,
    );
    my $shipment    = $order_details->{shipment_object};
    my $ship_item   = $shipment->shipment_items->first;

    my %state_recs  = (
        map { $_->id => $_ }
            $self->rs('Public::ShipmentItemReturnableState')->all
    );

    my %tests   = (
        "When State is 'No' result is FALSE" => {
            state_id    => $SHIPMENT_ITEM_RETURNABLE_STATE__NO,
            expected    => 0,
        },
        "When State is 'Yes' result is TRUE" => {
            state_id    => $SHIPMENT_ITEM_RETURNABLE_STATE__YES,
            expected    => 1,
        },
        "When State is 'CC Only' result is FALSE" => {
            state_id    => $SHIPMENT_ITEM_RETURNABLE_STATE__CC_ONLY,
            expected    => 0,
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test = $tests{ $label };

        # update the State Record to have to outcome wanted
        $state_recs{ $test->{state_id} }->discard_changes->update( { returnable_on_pws => $test->{expected} } );

        # update the Item Record to be for the wanted State
        $ship_item->discard_changes;
        $ship_item->update( { returnable_state_id => $test->{state_id} } );

        my $got = $ship_item->is_returnable_on_pws;
        ok( defined $got, "'is_returnable_on_pws' returned a defined value" );
        cmp_ok( $got, '==', $test->{expected}, "and is as expected: '" . $test->{expected} . "'" );
    }
}

=head2 test_get_reservation_to_link_to_by_pid

Tests the method 'get_reservation_to_link_to_by_pid' returns correct
reservation to link to.

=cut

sub test_get_reservation_to_link_to_by_pid : Tests() {
    my $self= shift;

    my $channel     = Test::XTracker::Data->any_channel;
    my $order_details = $self->{data}->new_order(
        products    => 3,
        channel     => $channel,
    );
    my $order       = $order_details->{order_object};
    my $customer    = $order_details->{customer_object};
    my $shipment    = $order_details->{shipment_object};
    my @ship_items  = $shipment->shipment_items->all;

    $order->update( { date => $self->schema->db_now() } );

    my $last_ship_item = pop @ship_items;
    my @reservations;
    foreach my $item ( @ship_items ) {
        push @reservations, _create_reservation( $customer, $item );
    }

    # create a Reservation with a Pre-Order for the last Shipment Item
    push @reservations, _create_reservation( $customer, $last_ship_item, { for_pre_order => 1 } );

    my $statuses    = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::ReservationStatus', {
        allow   => [ $RESERVATION_STATUS__UPLOADED, $RESERVATION_STATUS__CANCELLED, $RESERVATION_STATUS__PURCHASED ]
    } );

    note "Test : Reservation status not allowed";
    foreach my $status ( @{ $statuses->{not_allowed} } ) {
        $reservations[0]->update( { status_id => $status->id } );
        my $got = $ship_items[0]->get_reservation_to_link_to_by_pid;
        ok( !defined $got, "No Reservation was Found with Status: '" . $status->status . "'" );
    }
    note "Test: Reservation status for Allowed status";
    foreach my $status ( @{ $statuses->{allowed} } ) {
        $reservations[0]->update( { status_id => $status->id, commission_cut_off_date => $shipment->order->date->clone->add( hours => 1) } );
        $reservations[0]->discard_changes;
        my $got = $ship_items[0]->get_reservation_to_link_to_by_pid;
        isa_ok( $got, 'XTracker::Schema::Result::Public::Reservation', "Found a Reservation with Status: '" . $status->status . "'" );
        cmp_ok( $got->id, '==', $reservations[0]->id, "and the Reservation is the expected one" );
        my $link    = $ship_items[0]->link_with_reservation_by_pid( $got );
        isa_ok( $link, 'XTracker::Schema::Result::Public::LinkShipmentItemReservationByPid',
                    "call to 'link_with_reservation_by_pid' returned a link record" );
        cmp_ok( $link->reservation_id, '==', $reservations[0]->id, "and linked to the expected Reservation" );
        $ship_items[0]->link_shipment_item__reservation_by_pids->delete;      # get rid of it for future tests
    }


    note "Test : Reservation linked to Shipment Item";
    $reservations[0]->update( { variant_id => $ship_items[0]->variant_id, status_id => $RESERVATION_STATUS__UPLOADED  } );
    $ship_items[0]->link_with_reservation_by_pid($reservations[0]);
    #reservation is already linked, hence method should return undef
    my $got = $ship_items[0]->get_reservation_to_link_to_by_pid;
    ok( !defined $got, "No link was returned as expected ");

    note "Test: Reservation with status: Uploaded";
    $ship_items[0]->link_shipment_item__reservation_by_pids->delete; #delete the link
    #reservation is uploaded, method finds it
    my $link= $ship_items[0]->get_reservation_to_link_to_by_pid;
    cmp_ok( $link->id, '==', $reservations[0]->id, "Reservation is the expected one" );

    note "Test: Reservation with status: Cancelled but no cuttoff date";
    $ship_items[0]->link_shipment_item__reservation_by_pids->delete; #delete the link
    #reservation is cancelled but no cutoff date, method does not find it
    $reservations[0]->update( { status_id => $RESERVATION_STATUS__CANCELLED, commission_cut_off_date => undef });
    $link= $ship_items[0]->get_reservation_to_link_to_by_pid;
    ok( !defined $link, "No link was returned as expected ");

    note "Test: Reservation with status: Purchased and no cutoff date";
    $reservations[0]->update( { status_id => $RESERVATION_STATUS__PURCHASED, commission_cut_off_date => undef });
    #reservation is purchased but no cutoff date, method does not find it
    $link= $ship_items[0]->get_reservation_to_link_to_by_pid;
    ok( !defined $link, "No link was returned as expected ");

    note "Test: Reservation having different variants of same product and different creation dates";
    $self->_delete_link_shipment_item_to_reservation(\@ship_items);
    my $order_date = $shipment->order->date;
    $reservations[0]->update( { status_id => $RESERVATION_STATUS__UPLOADED, variant_id => $ship_items[0]->variant_id });
    $reservations[1]->update( { status_id => $RESERVATION_STATUS__PURCHASED, variant_id => $ship_items[0]->variant_id });
    $reservations[2]->update( { status_id => $RESERVATION_STATUS__CANCELLED,  variant_id => $ship_items[0]->variant_id });

    # when same variant, matches uploaded one first
    $link =  $ship_items[0]->get_reservation_to_link_to_by_pid;
    cmp_ok( $link->id, '==', $reservations[0]->id, "Reservation is the expected one" );

    my @variants = $ship_items[0]->product->variants;
    my @variants_to_use = grep { $_->id != $ship_items[0]->variant_id } @variants;
    my $today       = DateTime->now( time_zone => 'local' );
    my $past_date    = $today->clone->subtract( days => 5 );


    $ship_items[0]->update({  variant_id => $variants_to_use[0]->id });
    $reservations[0]->update({ status_id => $RESERVATION_STATUS__EXPIRED });
    $reservations[1]->update( {
         status_id => $RESERVATION_STATUS__CANCELLED,
         variant_id => $ship_items[0]->variant_id,
         commission_cut_off_date => $shipment->order->date
    });
    $reservations[2]->update( {
        status_id => $RESERVATION_STATUS__CANCELLED,
        variant_id => $variants_to_use[0]->id,
        commission_cut_off_date => $shipment->order->date,
        date_created => $past_date
    });
    $link =  $ship_items[0]->get_reservation_to_link_to_by_pid;
    # matches the cancelled one not linked to preorder by creation date.
    cmp_ok( $link->id, '==', $reservations[1]->id, "Reservation is the expected one" );

}

=head2 test_is_linked_to_reservation

tests the method 'is_linked_to_reservation' which returns true or false based
on if link_shipment_item_reservation or link_shipment_item_reservation_by_pids have
and entry for given shipment_item.

=cut

sub test_is_linked_to_reservation : Tests() {
    my $self = shift;

    # test if it returns true;
    my $channel     = Test::XTracker::Data->any_channel;
    my $order_details = $self->{data}->new_order(
        products    => 1,
        channel     => $channel,
    );
    my $customer    = $order_details->{customer_object};
    my $shipment    = $order_details->{shipment_object};
    my $item        = $shipment->shipment_items->first;

     my %tests   = (
        "when reservation is not created" => {
            args    => { delete => 1 },
            expected    => 0,
        },
        "Reservation is for Preorder" => {
            args    => { for_pre_order => 1},
            expected    => 1,
        },
        "Reservation is for sku" => {
            args        => {},
            expected    => 1,
        },
        "Reservation is for pid" => {
            args        => { reservation_for_pid => 1},
            expected    => 1,
        },

    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test = $tests{ $label };
        my $args = $test->{args};

        if( $args->{delete} ) {
            Test::XTracker::Data->delete_reservations( { variant => $item->variant } );
        } else {
            my $reservation =_create_reservation( $customer, $item, $args );
            $self->_link_shipment_item_to_reservation( $item, $reservation->id, $args );
        }
        cmp_ok( $item->is_linked_to_reservation, '==', $test->{expected}, " The link is as expected" );
    }

}
#----------------------------------------------------------------------------------------------------

sub _create_reservation {
    my ( $customer, $ship_item, $args ) = @_;

    # delete any existing Reservations for the variant
    Test::XTracker::Data->delete_reservations( { variant => $ship_item->variant } );

    my $reservation;

    if ( !$args->{for_pre_order} ) {
        my $data    = Test::XT::Data->new_with_traits( {
            traits  => [
                'Test::XT::Data::ReservationSimple',
            ],
        } );

        $data->channel( $customer->channel );
        $data->customer( $customer );
        $data->variant( $ship_item->variant );

        $reservation = $data->reservation;
    }
    else {
        $reservation = Test::XTracker::Data::PreOrder->create_pre_order_reservations( {
            channel     => $customer->channel,
            customer    => $customer,
            variants    => [ $ship_item->variant ],
            pre_order_item_status => $PRE_ORDER_ITEM_STATUS__EXPORTED,
        } )->[0];
    }

    $reservation->update( { status_id => $RESERVATION_STATUS__UPLOADED } );

    return $reservation->discard_changes;
}

sub test_cancel : Tests {
    my $self = shift;

    # TODO:
    # * Vouchers
    # * do_pws_update = 0
    # * no_allocate = 1
    # * default stock_manager
    # * there's a few branches of _do_cancel_pending that aren't being tested
    #   as we don't update the shipment item status - though these should
    #   probably be tested in another test, this one's plenty as it stands
    for (
        $self->schema->resultset('Public::ShipmentItemStatus')->search({},{order_by => 'id'})
    ) {
        my ( $item_status_id, $item_status ) = map { $_->id, $_->status } $_;
        subtest "test cancelling item with status of '$item_status'" => sub {
            my $shipment = $self->{data}->new_order->{shipment_object};

            my $shipment_item = $shipment->shipment_items->single;
            ok( $shipment_item->update({shipment_item_status_id => $item_status_id}),
                "set shipment item status to $item_status_id ($item_status)" );

            $self->_test_cancel(shipment_item => $shipment_item);
        };
    }
}

sub _test_cancel {
    my ($self,  $item, $customer_issue_type_id, $operator_id, $pws_action_id, $notes )
        = validated_list( \@_,
            shipment_item => { isa => 'XTracker::Schema::Result::Public::ShipmentItem', },
            customer_issue_type_id => {
                isa => 'Int', default => $CUSTOMER_ISSUE_TYPE__7__FABRIC,
            },
            operator_id => {
                isa => 'Int', default => $APPLICATION_OPERATOR_ID,
            },
            pws_action_id => {
                isa => 'Int', default => $PWS_ACTION__CANCELLATION,
            },
            notes => {
                isa => 'Str', default => 'Test shipment_item->cancel note',
            },
        );

    # Start our monitors so we can check for (un)expected messages
    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

    # Make a note of what status we expect *before* doing the cancellation
    my $expected_item_status_id = $item->_do_cancel_pending
                                ? $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
                                : $SHIPMENT_ITEM_STATUS__CANCELLED;

    my $shipment = $item->shipment;
    my $cancel_args = {
        operator_id => $operator_id,
        customer_issue_type_id => $customer_issue_type_id,
        pws_action_id => $pws_action_id,
        notes => $notes,
        stock_manager => $shipment->get_channel->stock_manager,
        do_pws_update => 1,
        no_allocate => 0,
    };
    my $can_cancel = $item->can_cancel;
    my $is_no_op = !!grep {
        $_->is_cancelled || $_->is_cancel_pending
    } $item;
    if ( $can_cancel || $is_no_op ) {
        $item->cancel($cancel_args);
    }
    else {
        throws_ok( sub { $item->cancel($cancel_args) },
            qr{^You can only cancel items},
            'cannot cancel items with status ' . $item->shipment_item_status->status
        );
    }
    # We skip these tests if calling cancel croaked or it was a no op
    SKIP: {
        skip q{Didn't cancel, skip tests}, 5 if !$can_cancel || $is_no_op;

        is( $item->shipment_item_status_id, $expected_item_status_id,
            'shipment item has correct status_id' );

        subtest 'test shipment_item_status_log row' => sub {
            isa_ok( my $item_status_log
                = $item->search_related('shipment_item_status_logs',
                    { shipment_item_status_id => $expected_item_status_id, }
                )->single, 'XTracker::Schema::Result::Public::ShipmentItemStatusLog'
            );
            is( $item_status_log->operator_id, $operator_id,
                'operator_id should match' );
            isa_ok( $item_status_log->date, 'DateTime' );
        };

        subtest 'test cancelled_item row' => sub {
            isa_ok( my $cancelled_item = $item->cancelled_item,
                'XTracker::Schema::Result::Public::CancelledItem' );
            is( $cancelled_item->customer_issue_type_id, $customer_issue_type_id,
                'customer_issue_type_id should match' );
            isa_ok( $cancelled_item->date, 'DateTime' );
        };

        subtest 'test log_pws_stock row' => sub {
            plan skip_all => q{Status set to 'Cancel Pending' so skip log_pws_stock tests}
                if $expected_item_status_id == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING;
            # I can't work out a better way to retrieve this row...
            isa_ok(
                my $log_pws_stock = $self->schema->resultset('Public::LogPwsStock')->search(
                    { date => { q{<} => \'now()' } },
                    { order_by => { -desc => 'date' } },
                )->slice(0,0)->single, 'XTracker::Schema::Result::Public::LogPwsStock'
            );
            for (
                [ variant_id    => $item->variant_id ],
                [ pws_action_id => $pws_action_id ],
                [ operator_id   => $operator_id ],
                [ notes         => $notes ],
                [ quantity      => 1 ],
                [ channel_id    => $shipment->get_channel->id ],
            ) {
                my ( $field_name, $expected_value ) = @$_;
                is( $log_pws_stock->$field_name, $expected_value, "$field_name should match" );
            }
        };

        subtest 'test expected messages' => sub {
            if ( XT::Warehouse->instance->has_prls ) {
                $xt_to_wms->expect_no_messages;
                $xt_to_prls->expect_messages({
                    messages => [{
                        type => 'allocate',
                        details => {
                            allocation_id => $shipment->allocations->single->id,
                        },
                    }],
                });
            }
            else {
                $xt_to_wms->expect_no_messages;
                $xt_to_prls->expect_no_messages;
            }
        };
    }
}

sub update_status : Tests {
    my $self = shift;

    my $shipment_item
        = $self->{data}->new_order->{shipment_object}->shipment_items->slice(0,0)->single;

    dies_ok(
        sub { $shipment_item->update_status },
        'dies with no arguments'
    );

    my $valid_status_id = $SHIPMENT_ITEM_STATUS__NEW;
    dies_ok(
        sub { $shipment_item->update_status($valid_status_id) },
        'dies without passing an $operator_id'
    );

    my $schema = $self->schema;
    my $operator_id = $APPLICATION_OPERATOR_ID;
    {
    my $invalid_status_id
        = $schema->resultset('Public::ShipmentItemStatus')->get_column('id')->max + 1;
    dies_ok(
        sub { $shipment_item->update_status($invalid_status_id, $operator_id) },
        'dies when passing invalid $shipment_item_status_id'
    );
    }

    {
    my $invalid_pea_id
        = $schema->resultset('Public::PackingExceptionAction')->get_column('id')->max + 1;
    dies_ok(
        sub { $shipment_item->update_status($valid_status_id, $operator_id, $invalid_pea_id) },
        'dies when passing invalid $packing_exception_action_id'
    );
    }

    for my $packing_exception_action_id ( undef, $PACKING_EXCEPTION_ACTION__MISSING ) {
        subtest sprintf( 'update with%s packing_exception_id',
            $packing_exception_action_id ? q{} : q{out}
        ) => sub {
            my $pre_update_log_count = $shipment_item->shipment_item_status_logs->count;
            # Make sure we pick a new status id - if there's no change we won't
            # log, causing a test failure below
            my $new_status_id = $schema->resultset('Public::ShipmentItemStatus')
                ->search({id => { q{!=} => $shipment_item->shipment_item_status_id} })
                ->slice(0,0)
                ->single
                ->id;
            lives_ok(
                sub { $shipment_item->update_status(
                    $new_status_id, $operator_id, ( $packing_exception_action_id // () )
                ) },
                'method call lives when passing valid arguments'
            );
            is( $shipment_item->discard_changes->shipment_item_status_id,
                $new_status_id, 'shipment item status updated' );
            is( $shipment_item->shipment_item_status_logs->count, $pre_update_log_count+1,
                'status transition logged' );

            my $si_log = last_shipment_item_status_log($shipment_item);
            isa_ok( $si_log->date, 'DateTime' );
            for (
                [ shipment_item_status_id     => $new_status_id,               ],
                [ operator_id                 => $operator_id,                 ],
                [ packing_exception_action_id => $packing_exception_action_id, ],
            ) {
                my ( $col, $expected ) = @$_;
                is( $si_log->$col, $expected, "$col logged correctly" );
            }
        };
    }
}

=head2 last_shipment_item_status_log( $shipment_item ) : $shipment_item_status_log

Returns the most recent shipment_item_status_log row object for the given
shipment item.

=cut

sub last_shipment_item_status_log {
    my $shipment_item = shift;
    return $shipment_item->search_related('shipment_item_status_logs', undef, {
        order_by => { -desc => 'date', }, rows => 1,
    })->single;
}

=head2 update_shipment_item_container_log

=cut

sub update_shipment_item_container_log : Tests {
    my ($self) = @_;

    # create some containers
    my @container_ids = Test::XT::Data::Container->get_unique_ids({ how_many => 3 });

    my $schema = $self->{schema};

    # I thought get_unique_ids creates the containers automatically, but apparently it doesn't
    $schema->resultset('Public::Container')->create({
        id => $_,
        status_id => $PUBLIC_CONTAINER_STATUS__AVAILABLE,
    }) foreach @container_ids;

    my ( $shipment_item, $log_rs, $old_container_id );
    subtest 'On shipment item creation' => sub {
        my $updated_after = $schema->db_now;
        # create a shipment with items in it
        my $fixture = Test::XT::Fixture::Fulfilment::Shipment
            ->new({ pid_count => 1 })
            ->with_picked_shipment;
        $old_container_id = $fixture->picked_container_id;
        $shipment_item = $fixture->shipment_row->shipment_items->first;

        $log_rs = $schema->resultset('Public::ShipmentItemContainerLog')
            ->search({shipment_item_id => $shipment_item->id});

        # check log
        $self->_test_container_logs(
            $shipment_item,
            { old_container_id => undef, new_container_id => $old_container_id },
            $updated_after,
        );
    };

    my $default_operator_id = $APPLICATION_OPERATOR_ID;
    my $another_operator = $schema->resultset('Public::Operator')->search(
        { id => { q{!=} => $default_operator_id } },
        { order_by => { -desc => 'last_login' }, rows => 1 }
    )->single;
    for (
        # Check we haven't broken regular updates
        [
            'Update an unrelated column',
            { unit_price => 42 },
            {},
        ],
        # Check we haven't broken inflation, as we mess with set_inflated_columns()
        [
            'Update an inflated column',
            # This gets overwritten with NOW() by a trigger though :/
            { last_updated => '2001-01-01 00:00:00' },
            {},
        ],
        [
            'Update logged column',
            { container_id => $container_ids[0] },
            {
                old_container_id => $old_container_id,
                new_container_id => $container_ids[0],
                operator_id      => $default_operator_id,
            },
        ],
        [
            'Update with a given operator',
            { container_id => $container_ids[1], operator_id  => $another_operator->id, },
            {
                old_container_id => $container_ids[0],
                new_container_id => $container_ids[1],
                operator_id      => $another_operator->id,
            },
        ],
        [
            'Removing the container',
            { container_id => undef },
            { old_container_id => $container_ids[1], new_container_id => undef, },
        ],
    ) {
        my ( $test_name, $update_args, $expected ) = @$_;
        subtest $test_name => sub {
            my $updated_after = $schema->db_now;
            $shipment_item->update($update_args);
            $self->_test_container_logs($shipment_item, $expected, $updated_after);
        };
    }
}

sub _test_container_logs {
    my ( $self, $si, $cols, $updated_after ) = @_;
    my @logs = $si->search_related(
        'shipment_item_container_logs',
        { created_at => {
            q{>} => $si->result_source->schema->format_datetime($updated_after)
        } }
    )->all;
    unless ( keys %$cols ) {
        is( @logs, 0, 'should not have logged' );
        return;
    }
    is( @logs, 1, 'should have logged once' );
    is(
        $logs[0]->$_, $cols->{$_}, "'$_' should have logged correctly"
    ) for sort keys %$cols;
}

sub test_price_adjustment : Tests {
    my ($self) = @_;

    my $channel = Test::XTracker::Data->any_channel;

    my ( undef, $pids ) = Test::XTracker::Data->grab_products( {channel_id => $channel->id, force_create => 1} );
    my $variant = $pids->[0]->{variant};

    my $shipment = $self->db__samples__create_shipment({
        channel_id    => $channel->id,
        variant_id    => $variant->id,
        shipment      => { shipment_status_id => $SHIPMENT_ITEM_STATUS__NEW },
        shipment_item => { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW },
    });

    # Create a shipment item
    my $shipment_item = Test::XTracker::Model->create_shipment_item({
        shipment_id => $shipment->id,
        variant_id  => $variant->id
    });

    # Get the shipment item's price adjustment - this should not trigger a warning in the logs.
    warnings_are {$shipment_item->price_adjustment()} [], "Price adjustment sub shouldn't trigger a warning.";
}

sub test_is_being_picked : Tests {
    my $self = shift;

    my $schema = $self->{schema};

    # TODO: test for allocation_item_count 0 (i.e. under IWS)
    my $allocation_item_count = 1;
    my $mock_count = Test::MockModule->new('XTracker::Schema::ResultSet::Public::AllocationItem');
    $mock_count->mock(count => $allocation_item_count);

    # Test for XT with PRL
    for my $ai_status (
        $schema->resultset('Public::AllocationItemStatus')->search({}, {order_by => 'id'})
    ) {
        my $shipment_item = Test::MockObject::Extends->new(
            $schema->resultset('Public::ShipmentItem')->new({})
        );
        # active_allocation_item just checks the is_end_state column, so it's
        # easy to mock
        $shipment_item->mock(active_allocation_item => sub {
            $ai_status->is_end_state
          ? undef
          : $schema->resultset('Public::AllocationItem')->new({status_id => $ai_status->id});
        });
        # A shipment item is only being picked if its active allocation
        # item has a status of 'picking'
        my $msg = sprintf
            q{calling is_being_picked with a shipment item with an allocation item with status '%s' should return},
            $ai_status->status;
        if ( $ai_status->id == $ALLOCATION_ITEM_STATUS__PICKING ) {
            ok( $shipment_item->is_being_picked, "$msg true" );
        }
        else {
            ok( !$shipment_item->is_being_picked, "$msg false" );
        }
    }
}

=head2 _link_shipment_item_to_reservation

Links shipment_item to reservation for given
shipment_item and reservation_id

=cut

sub _link_shipment_item_to_reservation {
    my $self            = shift;
    my $shipment_item   = shift;
    my $reservation_id  = shift;
    my $args            = shift;

    my $schema = $self->{schema};
    if($args->{reservation_for_pid}) {
        $shipment_item->create_related('link_shipment_item__reservation_by_pids', {
            reservation_id => $reservation_id,
        } );

    } else {
        $shipment_item->create_related('link_shipment_item__reservations', {
            reservation_id => $reservation_id,
        } );
    }

}

=head2 _delete_link_shipment_item_to_reservation

For given shipment_item[s], delete all the links to reservations.

=cut

sub _delete_link_shipment_item_to_reservation {
    my $self  = shift;
    my $items = shift;

    $items = ( ref $items eq 'ARRAY' ) ? $items : [ $items ] ;

    foreach my $item (@$items) {
        $item->link_shipment_item__reservations->delete;
        $item->link_shipment_item__reservation_by_pids->delete;
    }

}
