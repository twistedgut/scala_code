#!/usr/bin/env perl

use NAP::policy "tt",     qw( test );


use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Data::Email;
use Test::XT::Data;

use XTracker::Config::Local                 qw( config_var );
use XTracker::Constants                     qw( :application );
use XTracker::Constants::FromDB             qw(
                                                :reservation_status
                                                :flow_status
                                                :shipment_item_status
                                                :product_channel_transfer_status
                                                :department
                                                :authorisation_level
                                                :pre_order_item_status
                                            );
use XTracker::Database::Reservation         qw( :email update_reservation_ordering cancel_reservation );
use XTracker::WebContent::StockManagement;

use XTracker::Comms::DataTransfer           qw( list_reservations transfer_product_reservations );

use DateTime;
use Data::Dump      qw( pp );

use XTracker::Constants::FromDB qw(
    :pws_action
);


# get a schema to query
my $schema = Test::XTracker::Data->get_schema;
isa_ok($schema, 'XTracker::Schema',"Schema Created");

#------------ Run Tests ------------
_test_reservation_ordering( $schema, 1 );
_test_auto_upload( $schema, 1 );
_test_update_operator( $schema, 1 );
_test_can_update_operator( $schema, 1 );
_test_uploading_pre_order_reservations( $schema, 1 );
_test_cancelling_pre_order_reservations( $schema, 1 );
#-----------------------------------

done_testing;


# tests stuff to do with the 'ordering_id' which is used to prioritise reservations
sub _test_reservation_ordering {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_reservation_ordering", 1        if ( !$oktodo );

        note "TESTING '_test_reservation_ordering'";

        my $rs  = $schema->resultset('Public::Reservation');
        isa_ok($rs, 'XTracker::Schema::ResultSet::Public::Reservation',"Reservation Result Set");

        $schema->txn_do( sub {
            my($channel, $pids) = Test::XTracker::Data->grab_products({how_many => 1});
            my $variant = $pids->[0]{variant};
            # cancel any reservations for the SKU
            $variant->reservations->update( { status_id => $RESERVATION_STATUS__CANCELLED } );

            my $customer_1 = Test::XTracker::Data->create_test_customer(channel_id => $channel->id);
            my $customer_2 = Test::XTracker::Data->create_test_customer(channel_id => $channel->id);

            # arguments required for the 'XTracker::Comms::DataTransfer::list_reservations' function
            # which also brings back a list of Reservations for the Product Upload process
            my $list_reservation_args   = {
                                            dbh         => $schema->storage->dbh,
                                            product_ids => $variant->product_id,
                                            channel_id  => $channel->id,
                                        };

            my @customers;
            my @reservations;
            my $position = 1;

            for my $customer_id ($customer_1, $customer_2) {
                my $customer = $schema->resultset('Public::Customer')->find({id => $customer_id});
                push @customers, $customer;

                for (1 .. 5) {
                    my $reservation = $customer->create_related('reservations', {
                        channel_id  => $channel->id,
                        variant_id  => $pids->[0]->{variant_id},
                        ordering_id => $position,
                        operator_id => 1,
                        status_id   => $RESERVATION_STATUS__PENDING,
                        reservation_source_id => $schema->resultset('Public::ReservationSource')->search->first->id,
                        reservation_type_id => $schema->resultset('Public::ReservationType')->search->first->id,
                    });

                    is($reservation->ordering_id, $position, 'Ordering of reservation ' . $reservation->id . " set to $position");

                    push(@reservations, $reservation);

                    $position++;
                }
            }

            # update one of the Customer's to be Uploaded
            $customers[0]->reservations->update( { status_id => $RESERVATION_STATUS__UPLOADED } );

            my @pending             = $variant->reservations->pending_in_priority_order->all;
            cmp_ok( @pending, '==', 5, "Got expected number of 'Pending' Reservations: 5" );
            foreach my $idx ( 0..$#pending ) {
                cmp_ok( $pending[$idx]->ordering_id, '==', $idx + 6, "'ordering_id' for Reservation ".($idx+1)." is '".($idx+6)."'" );
            }
            my @by_variant  = $rs->by_variant_id( $variant->id )->pending_in_priority_order->all;
            is_deeply(
                [map { +{ $_->get_columns } } @by_variant],
                [map { +{ $_->get_columns } } @pending],
                "using 'by_variant_id' method returns the same as going via the 'Public::Variant->reservations' relationship"
            );
            my @list_reservations   = _call_list_reservations( $variant, $list_reservation_args );
            cmp_ok( @list_reservations, '==', 5,
                                "Got expected number of 'Pending' Reservations from 'XTracker::Comms::DataTransfer::list_reservations' function: 5" );
            is_deeply( [ map { $_->{reservation_id} } @list_reservations ], [ map { $_->id } @pending ],
                                "using 'list_reservations' function returns Reservations in the same order as 'pending_in_priority_order' method" );

            # set to purchased
            $reservations[2]->update( { status_id => $RESERVATION_STATUS__UPLOADED } );
            ok($reservations[2]->set_purchased, 'Set reservation 3 as purchased');

            # reset rows to get changed ordering_ids
            $_->discard_changes for @reservations;

            is($reservations[2]->ordering_id, 0, 'Ordering of reservation ' . $reservations[2]->id . ' changed to 0');
            is($reservations[2]->status_id, $RESERVATION_STATUS__PURCHASED, 'Status changed');

            is($reservations[0]->ordering_id, 1, 'Ordering of reservation ' . $reservations[0]->id . ' 1 still 1');
            is($reservations[1]->ordering_id, 2, 'Ordering of reservation ' . $reservations[1]->id . ' 2 still 2');

            for (3 .. 9) {
                is($reservations[ $_ ]->ordering_id, $_, 'Ordering of reservation ' . $reservations[ $_ ]->id . ' changed to ' . $_);
            }

            # now set_purchased again and with it's current position of ZERO
            # it should not change any other 'ordering_id' of other reservations
            note "call 'set_purchased' again on 3rd Reservation to check 'ordering_id' doesn't change when current position is ZERO";
            $reservations[2]->discard_changes->set_purchased;
            $_->discard_changes for @reservations;          # reset rows to get changed ordering_ids
            for (3 .. 9) {
                is($reservations[ $_ ]->ordering_id, $_, 'Ordering of reservation ' . $reservations[ $_ ]->id . ' still at ' . $_);
            }

            note "now use 'update_reservation_ordering' function to update the same Reservation as above and do the same check";
            update_reservation_ordering(
                                            $schema->storage->dbh,
                                            0,      # current position,
                                            0,      # new position,
                                            $reservations[2]->id,
                                            $reservations[2]->variant_id,
                                            $reservations[2]->channel_id,
                                        );
            $_->discard_changes for @reservations;          # reset rows to get changed ordering_ids
            for (3 .. 9) {
                is($reservations[ $_ ]->ordering_id, $_, 'Ordering of reservation ' . $reservations[ $_ ]->id . ' still at ' . $_);
            }

            note "use 'update_reservation_ordering' to change the ordering of other reservations";
            my %tests   = (
                    'move position 4 to 6'  => {
                            reservation_to_move => $reservations[4],
                            new_position        => 6,
                            reservation_list    => [ @reservations[ 3..9 ] ],
                            expected_order      => [ 3,6,4,5,7,8,9 ],
                        },
                    'move position 7 to 4'  => {
                            reservation_to_move => $reservations[7],
                            new_position        => 4,
                            reservation_list    => [ @reservations[ 3..9 ] ],
                            expected_order      => [ 3,5,6,7,4,8,9 ],
                        },
                    'move position 3 to 0'  => {
                            reservation_to_move => $reservations[3],
                            new_position        => 0,
                            reservation_list    => [ @reservations[ 3..9 ] ],
                            expected_order      => [ 0,3,4,5,6,7,8 ],
                        },
                    'move position 7 to 0'  => {
                            reservation_to_move => $reservations[7],
                            new_position        => 0,
                            reservation_list    => [ @reservations[ 3..9 ] ],
                            expected_order      => [ 3,4,5,6,0,7,8 ],
                        },
                );

            foreach my $label ( keys %tests ) {
                note "test: $label";
                my $test    = $tests{ $label };
                my $res_to_move = $test->{reservation_to_move}->discard_changes;

                update_reservation_ordering(
                                                $schema->storage->dbh,
                                                $res_to_move->ordering_id,
                                                $test->{new_position},
                                                $res_to_move->id,
                                                $res_to_move->variant_id,
                                                $res_to_move->channel_id,
                                            );

                foreach my $idx ( 0..$#{ $test->{reservation_list} } ) {
                    my $res_moved   = $test->{reservation_list}[ $idx ];
                    my $expect_pos  = $test->{expected_order}[ $idx ];
                    cmp_ok( $res_moved->discard_changes->ordering_id, '==', $expect_pos,
                                            "Reservation: " . $res_moved->id . " at expected position: " . $expect_pos );
                    # update them to their original order
                    $res_moved->update( { ordering_id => ( $idx + 3 ) } );
                }
            }
            $_->discard_changes for @reservations;          # reset rows to get changed ordering_ids


            note "Now test with Pre-Orders to make sure they take priotiy over normal Reservations";
            @reservations   = @reservations[5..9];      # lose the first 5 which shouldn't be included in the next set of tests

            # create a few Pre-Orders with the Same Variant as above
            my @pre_order_reservations;
            foreach my $counter ( 1..3 ) {
                push @pre_order_reservations, Test::XTracker::Data::PreOrder->create_pre_order_reservations( { variants => [ $variant ] } )->[0];
                # update the Times on their Status Log Record so they don't
                # all have the same and the earliest should always be first
                my $log = $pre_order_reservations[-1]->pre_order_items->first
                                    ->unique_complete_pre_order_item_status_logs->first;
                $log->update( { date => \"date + interval '${counter} second'" } );
            }
            my $max_ordering_id = $variant->reservations->get_column('ordering_id')->max() + scalar( @pre_order_reservations );

            my @expected_ids= map { $_->id } ( @pre_order_reservations, @reservations );
            @pending    = $variant->reservations->pending_in_priority_order->all;
            cmp_ok( @pending, '==', 8, "'pending_in_priority_order' returns list of Normal Reservations plus Pre-Order Reservations: 8" );
            is_deeply( [ map { $_->id } ( @pending ) ], \@expected_ids, "and returned the list in the correct sequence with Pre-Orders first" );
            @by_variant = $rs->pending_in_priority_order->by_variant_id( $variant->id )->all;
            is_deeply(
                [map { +{ $_->get_columns } } @by_variant],
                [map { +{ $_->get_columns } } @pending],
                "using 'by_variant_id' method returns the same as going via the 'Public::Variant->reservations' relationship"
            );
            @list_reservations  = _call_list_reservations( $variant, $list_reservation_args );
            is_deeply( [ map { $_->{reservation_id} } @list_reservations ], \@expected_ids,
                                    "using 'list_reservations' function also returns the same" );

            note "alter Pre-Order Reservation's 'ordering_id' values, should make NO difference";
            $pre_order_reservations[0]->update( { ordering_id => $max_ordering_id } );
            $pre_order_reservations[1]->update( { ordering_id => ( $max_ordering_id - 2 ) } );
            $pre_order_reservations[2]->update( { ordering_id => ( $max_ordering_id - 1 ) } );
            @pending        = $variant->reservations->pending_in_priority_order->all;
            is_deeply( [ map { $_->id } ( @pending ) ], \@expected_ids,
                                                "list still in the correct sequence with Pre-Orders first and in their 'pre_order_item.id' order" );
            @list_reservations  = _call_list_reservations( $variant, $list_reservation_args );
            is_deeply( [ map { $_->{reservation_id} } @list_reservations ], \@expected_ids,
                                                "'list_reservations' function returns the correct sequence too" );

            note "alter some Normal Reservation's 'ordering_id' values, this SHOULD make a difference";
            $reservations[1]->update( { ordering_id => ( $reservations[1]->ordering_id + 2 ) } );
            $reservations[3]->update( { ordering_id => ( $reservations[3]->ordering_id - 2 ) } );
            @expected_ids   = map { $_->id } ( @pre_order_reservations, @reservations[0,3,2,1,4] );
            @pending        = $variant->reservations->pending_in_priority_order->all;
            is_deeply( [ map { $_->id } ( @pending ) ], \@expected_ids, "list still in the correct sequence" );
            @list_reservations  = _call_list_reservations( $variant, $list_reservation_args );
            is_deeply( [ map { $_->{reservation_id} } @list_reservations ], \@expected_ids,
                                                "'list_reservations' function returns the correct sequence too" );

            note "scatter Pre-Order Reservations amongst Normal Reservations, Pre-Order SHOULD still come first";
            my $ordering_id = $reservations[0]->ordering_id;
            foreach my $reservation (
                                        $reservations[0],
                                        $pre_order_reservations[0],
                                        $reservations[1],
                                        $pre_order_reservations[2],
                                        $reservations[3],
                                        $pre_order_reservations[1],
                                        $reservations[4],
                                        $reservations[2],
                                    ) {
                $reservation->update( { ordering_id => $ordering_id } );
                $ordering_id++;
            }
            @expected_ids   = map { $_->id } @pre_order_reservations, sort { $a->ordering_id <=> $b->ordering_id } @reservations;
            @pending        = $variant->reservations->pending_in_priority_order->all;
            is_deeply( [ map { $_->id } ( @pending ) ], \@expected_ids, "list still has Pre-Order Reservations first followed by Normal Reservations" );
            @list_reservations  = _call_list_reservations( $variant, $list_reservation_args );
            is_deeply( [ map { $_->{reservation_id} } @list_reservations ], \@expected_ids,
                                                "'list_reservations' function returns the correct sequence too" );

            # when Pre-Order Reservations share the same Status Log Date, then their Ordering Id
            # should be used, but they should still be sorted ahead of Normal Reservations
            note "make all the Pre-Order Items have the same 'Complete' Status Log Dates so that Ordering Id should be used when Sorting";
            my $log_to_use  = $pre_order_reservations[0]->pre_order_items->first
                                            ->unique_complete_pre_order_item_status_logs->first;
            foreach my $reservation ( @pre_order_reservations ) {
                my $log = $reservation->pre_order_items->first
                                        ->unique_complete_pre_order_item_status_logs->first;
                $log->update( { date => $log_to_use->date } );
            }

            @expected_ids   = map { $_->id } @pre_order_reservations[0,2,1], sort { $a->ordering_id <=> $b->ordering_id } @reservations;
            @pending        = $variant->reservations->pending_in_priority_order->all;
            is_deeply( [ map { $_->id } ( @pending ) ], \@expected_ids,
                                "list still has Pre-Order Reservations first in Ordering Id sequence, followed by Normal Reservations" );
            @list_reservations  = _call_list_reservations( $variant, $list_reservation_args );
            is_deeply( [ map { $_->{reservation_id} } @list_reservations ], \@expected_ids,
                                                "'list_reservations' function returns the correct sequence too" );

            note "duplicate a Pre-Order Item Status 'Complete' Log entry, it should not be duplicated in the List functions";
            $log_to_use->pre_order_item->create_related('pre_order_item_status_logs', {
                                                                    pre_order_item_status_id=> $PRE_ORDER_ITEM_STATUS__COMPLETE,
                                                                    operator_id             => $log_to_use->operator_id,
                                                                    date                    => $log_to_use->date,
                                                            } );

            @pending        = $variant->discard_changes->reservations->pending_in_priority_order->all;
            cmp_ok( @pending, '==', 8, "'pending_in_priority_order' STILL returns list of 8 Reservations" );
            is_deeply( [ map { $_->id } ( @pending ) ], \@expected_ids,
                                "list still has Pre-Order Reservations first in Ordering Id sequence, followed by Normal Reservations" );
            @list_reservations  = _call_list_reservations( $variant, $list_reservation_args );
            is_deeply( [ map { $_->{reservation_id} } @list_reservations ], \@expected_ids,
                                                "'list_reservations' function returns the correct sequence too" );


            # rollback changes
            $schema->txn_rollback;
        } );
    };

    return;
}

# this will test the functionality to automatically upload
# Pending Reservations when stock is increased for a SKU
sub _test_auto_upload {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_auto_upload", 1         if ( !$oktodo );

        note "TESTING '_test_auto_upload'";

        my $reserv_rs       = $schema->resultset('Public::Reservation');
        my $reserv_max_log  = $schema->resultset('Public::ReservationLog')->get_column('id');

        my %reserv_statuses = map { $_->id => $_ } $schema->resultset('Public::ReservationStatus')->all;

        # find an Operator that isn't $APPLICATION_OPERATOR_ID and has a department
        my $operator    = $schema->resultset('Public::Operator')->search( {
                                                                            id  => { '!=' => $APPLICATION_OPERATOR_ID },
                                                                            disabled => 0,
                                                                            department_id => {'>', 0},
                                                                        } )->first;
        $operator->update( { department_id => $DEPARTMENT__CUSTOMER_CARE } );

        # delete any messages for or sent by the Operator
        $operator->sent_messages->delete;
        $operator->received_messages->delete;

        # overload 'get_web_stock_level' to always return 100
        my $web_stock_level = 100;
        no warnings 'redefine';
        *XTracker::WebContent::StockManagement::OurChannels::get_web_stock_level   = sub { return $web_stock_level; };
        use warnings 'redefine';

        $schema->txn_do( sub {
            my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
                                                                how_many => 1,
                                                                channel => Test::XTracker::Data->channel_for_nap,
                                                                ensure_stock_all_variants => 1,
                                                            } );
            my $variant     = $pids->[0]{variant};
            my $prod_chann  = _clean_up_system_for_variant( $variant, $channel );

            my $stock_manager   = XTracker::WebContent::StockManagement->new_stock_manager( {
                                                                schema      => $schema,
                                                                channel_id  => $channel->id,
                                                        } );

            # create localised versions of the email addresses that could be used
            Test::XTracker::Data::Email->create_localised_email_for_config_setting( $channel, 'personalshopping_email', 'fr_FR' );
            Test::XTracker::Data::Email->create_localised_email_for_config_setting( $channel, 'fashionadvisor_email', 'fr_FR' );
            Test::XTracker::Data::Email->create_localised_email_for_config_setting( $channel, 'customercare_email', 'fr_FR' );

            # check the '_get_true_qty_change' method
            _check__get_true_qty_change__method( $stock_manager );

            # create several reservations to use in the tests
            my @reservs = _create_reservations( 7, $channel, $variant, $operator );

            note "check using 'upload_pending' method";

            # change the status to be anything but 'Pending' to test it does nothing
            my @do_nothing  = grep { $_->id != $RESERVATION_STATUS__PENDING } values %reserv_statuses;
            foreach my $status ( @do_nothing ) {
                $reservs[0]->update( { status_id => $status->id } );
                cmp_ok( $reservs[0]->upload_pending( $APPLICATION_OPERATOR_ID, $stock_manager ), '==', 0,
                                                "when Reservation Status is: ".$status->status." does nothing" );
            }

            # make the Reservation 'Pending' again and then actually do an upload
            $reservs[0]->update( { status_id => $RESERVATION_STATUS__PENDING } );
            cmp_ok( $reservs[0]->upload_pending( $APPLICATION_OPERATOR_ID, $stock_manager ), '==', 1, "Reservation Status set to 'Pending' does something" );
            _check_reservation_ok( $reservs[0], 1 );
            # upload a different Reservation to check Balance is ok
            cmp_ok( $reservs[1]->upload_pending( $APPLICATION_OPERATOR_ID, $stock_manager ), '==', 1, "Another Reservation is Uploaded" );
            my $prev_log    = _check_reservation_ok( $reservs[1], 2 );


            note "check using 'notify_of_auto_upload'";

            # change the status to be anything but 'Uploaded' to test it does nothing
            @do_nothing = grep { $_->id != $RESERVATION_STATUS__UPLOADED } values %reserv_statuses;
            foreach my $status ( @do_nothing ) {
                $reservs[0]->update( { status_id => $status->id } );
                ok( !defined $reservs[0]->notify_of_auto_upload( $APPLICATION_OPERATOR_ID ),
                                                "when Reservation Status is: ".$status->status." does nothing" );
            }

            # check Reservations for Pre-Orders don't get notified even if they've been Uploaded
            my $pre_order_reservations  = Test::XTracker::Data::PreOrder->create_pre_order_reservations;
            $pre_order_reservations->[0]->update( { status_id => $RESERVATION_STATUS__UPLOADED } );
            ok( !defined $pre_order_reservations->[0]->notify_of_auto_upload( $APPLICATION_OPERATOR_ID ),
                                                "when a Reservation is for a Pre-Order it does nothing" );

            # make the Normal Reservation 'Uploaded' again and then actually notify
            $reservs[0]->update( { status_id => $RESERVATION_STATUS__UPLOADED } );
            my $params  = $reservs[0]->notify_of_auto_upload( $APPLICATION_OPERATOR_ID );
            isa_ok( $params, 'HASH', "when Reservation is Uploaded returns a HashRef of Params" );
            _check_notify_ok( $reservs[0], $APPLICATION_OPERATOR_ID, $params );
            # notify another Reservation with a different Sender Operator Id
            $params = $reservs[1]->notify_of_auto_upload( $operator->id );
            _check_notify_ok( $reservs[1], $operator->id, $params );


            note "check using 'auto_upload_pending'";

            # set-up the args used by the 'auto_upload_pending' method
            my $args    = {
                    stock_quantity  => 3,       # should auto upload 3 reservations
                    variant_id      => $variant->id,
                    channel         => $channel,
                    stock_manager   => $stock_manager,
                };

            # Turn off the Sales Channel from being able to Auto-Upload Reservations
            # so can test a call to the method that should return zero stock used
            _switch_auto_upload_config( $channel, 'Off' );
            my $stock_used  = $reserv_rs->auto_upload_pending( $args );
            ok( defined $stock_used && $stock_used == 0, "When config Turned Off method returns ZERO" );


            # re-order some of the 'ordering_id' to make sure
            # things are done in priotity order and not id order
            $reservs[2]->update( { ordering_id => 7 } );
            $reservs[6]->update( { ordering_id => 3 } );
            $reservs[3]->update( { ordering_id => 6 } );
            $reservs[5]->update( { ordering_id => 4 } );

            # Turn on the Config for the Sales Channel
            _switch_auto_upload_config( $channel, 'On' );

            # auto upload 3 reservations, it should upload $reservs[4,5,6]
            cmp_ok( $reserv_rs->auto_upload_pending( $args ), '==', 3, "Auto Uploaded Using a Stock Qty of 3 and Stock Used was 3" );
            cmp_ok( @{ $stock_manager->_emails }, '==', 3, "Stock Manager Email Array has 3 Elements" );
            my @emails  = @{ $stock_manager->_emails };
            foreach my $reserv ( @reservs[ 6, 5, 4 ] ) {        # loop through them in the order they should have been applied
                my $log = _check_reservation_ok( $reserv->discard_changes, $prev_log->balance + 1 );
                cmp_ok( $log->id, '>', $prev_log->id, "Reservation Log Id is greater than previous" );
                $prev_log   = $log;

                # check the Reservation Notification is ok
                my $email   = shift @emails;
                cmp_ok( $email->{reservation}->id, '==', $reserv->id, "Email Reservation Id as Expected" );
                _check_notify_ok( $reserv, $APPLICATION_OPERATOR_ID, $email->{email_params} );
            }
            foreach my $reserv ( @reservs[ 2, 3 ] ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            # only auto upload 1 reservation when 2 are available
            $args->{stock_quantity} = 1;
            $args->{operator_id}    = $operator->id;
            cmp_ok( $reserv_rs->auto_upload_pending( $args ), '==', 1, "Auto Uploaded Using a Stock Qty of 1 with 2 Reservations and Stock Used was 1" );
            cmp_ok( @{ $stock_manager->_emails }, '==', 4, "Stock Manager Email Array now has 4 Elements" );
            $prev_log   = _check_reservation_ok( $reservs[3]->discard_changes, $prev_log->balance + 1, $operator->id );
            _check_notify_ok( $reservs[3], $operator->id, $stock_manager->_emails->[3]->{email_params} );
            cmp_ok( $reservs[2]->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reservs[2]->id. " still Pending" );

            # request to auto upload 2 reservation when only 1 is available
            $args->{stock_quantity} = 2;
            cmp_ok( $reserv_rs->auto_upload_pending( $args ), '==', 1, "Auto Uploaded Using a Stock Qty of 2 but only 1 Reservation and Stock Used was 1" );
            cmp_ok( @{ $stock_manager->_emails }, '==', 5, "Stock Manager Email Array now has 5 Elements" );
            $prev_log   = _check_reservation_ok( $reservs[2]->discard_changes, $prev_log->balance + 1, $operator->id );
            _check_notify_ok( $reservs[2], $operator->id, $stock_manager->_emails->[4]->{email_params} );
            cmp_ok( $prev_log->id, '==', $reserv_max_log->max(), "Reservation's Log is also the Last Log Record, so no other Reservations were used" );

            # request to auto upload reservations when there are no 'Pending' ones available
            cmp_ok( $reserv_rs->auto_upload_pending( $args ), '==', 0,
                                                    "Auto Uploaded Using a Stock Qty of 2 when there are NO Pending Reservations and Stock Used was 0" );
            cmp_ok( $prev_log->id, '==', $reserv_max_log->max(), "Previous Reservation's Log is still the Last Log Record created" );

            $stock_manager->_clear_emails();
            cmp_ok( @{ $stock_manager->_emails }, '==', 0, "After Clearing the Emails there are NO Emails" );


            note "Check the 'XTracker::WebContent::StockManagement' object Auto Uploads Reservations Properly";

            my $email_die   = 0;
            my $emails_died = 0;
            my $emails_sent = 0;
            my @email_addresses;

            # override the 'send_email' function so we can capture what it's trying to send
            no warnings 'redefine';
            *XTracker::WebContent::StockManagement::OurChannels::send_customer_email = sub {
                if ( $email_die ) {
                    $emails_died++;
                    die "'send_customer_emails' DIEing";
                }
                $emails_sent++;
                push @email_addresses, $_[0]->{to};     # record what the To address was
                return 1;
            };
            use warnings 'redefine';

            # get a new instance of the Stock Manager with the send_email function overridden
            $stock_manager  = XTracker::WebContent::StockManagement->new_stock_manager( {
                                                                schema      => $schema,
                                                                channel_id  => $channel->id,
                                                        } );

            # set-up the args used by the 'stock_update' method
            my %stock_args  = (
                quantity_change => 3,
                variant_id      => $variant->id,
                pws_action_id   => $PWS_ACTION__ORDER,
            );

            # set all the previous reservations to be purchased and
            # out of the way of the new ones that will be created
            foreach my $reserv ( @reservs ) {
                $reserv->update( { status_id => $RESERVATION_STATUS__PURCHASED, ordering_id => 0 } );
            }

            # create some new reservations
            @reservs    = _create_reservations( 12, $channel, $variant, $operator );

            # call using internal method '_auto_upload_pending_reservations' that stock used is correct
            cmp_ok( $stock_manager->_auto_upload_pending_reservations( $variant->id, 1, $APPLICATION_OPERATOR_ID ), '==', 1,
                                        "using internal '_auto_upload_pending_reservations' method Stock Used as expected: 1" );
            $prev_log   = _check_reservation_ok( $reservs[0]->discard_changes, 1 );
            _check_notify_ok( $reservs[0], $APPLICATION_OPERATOR_ID, $stock_manager->_emails->[0]->{email_params} );
            foreach my $reserv ( @reservs[ 1..11 ] ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            # check sending emails using the '_send_emails' method works
            $stock_manager->_send_emails;
            _check_emails_sent_ok( $stock_manager, '_send_emails', \$emails_sent, \@email_addresses, [ $reservs[0] ] );

            note "now use the proper 'stock_update' method to upload multiple Reservations";

            note "first check passing a negative stock update does nothing";
            $stock_manager->stock_update( %stock_args, quantity_change => -1 );
            foreach my $reserv ( @reservs[ 1..11 ] ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            note "check passing 'skip_upload_reservations' doesn't upload the Pending Reservations";
            $stock_manager->stock_update( %stock_args, skip_upload_reservations => 1 );
            foreach my $reserv ( @reservs[ 1..11 ] ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            note "check that, when the Product's 'product_channel' record has a status of not 'None', nothing gets Uploaded";
            foreach my $status_id (
                                    $PRODUCT_CHANNEL_TRANSFER_STATUS__REQUESTED,
                                    $PRODUCT_CHANNEL_TRANSFER_STATUS__IN_PROGRESS,
                                    $PRODUCT_CHANNEL_TRANSFER_STATUS__TRANSFERRED
                                ) {
                $prod_chann->update( { transfer_status_id => $status_id } );
                $stock_manager->stock_update( %stock_args );
                foreach my $reserv ( @reservs[ 1..11 ] ) {
                    cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
                }
            }
            # update the Product Channel Transfer Status to 'None' so that the rest of the tests work
            $prod_chann->update( { transfer_status_id => $PRODUCT_CHANNEL_TRANSFER_STATUS__NONE } );

            note "now check passing Stock Quantity of 3 Uploads 3 Reservations";
            $stock_manager->stock_update( %stock_args );
            @emails = @{ $stock_manager->_emails }[ 0..2 ];
            foreach my $reserv ( @reservs[ 1..3 ] ) {
                $prev_log   = _check_reservation_ok( $reserv->discard_changes, $prev_log->balance + 1 );
                my $email   = shift @emails;
                _check_notify_ok( $reserv, $APPLICATION_OPERATOR_ID, $email->{email_params} );
            }
            foreach my $reserv ( @reservs[ 4..11 ] ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            # check sending emails using the '_post_commit' method works
            $stock_manager->_post_commit;
            _check_emails_sent_ok( $stock_manager, '_post_commit', \$emails_sent, \@email_addresses, [ @reservs[ 1..3 ] ] );

            note "now upload again this time with a different Operator Id";
            $stock_args{quantity_change}    = 1;
            $stock_manager->stock_update( %stock_args, operator_id => $operator->id );
            $prev_log   = _check_reservation_ok( $reservs[4]->discard_changes, $prev_log->balance + 1, $operator->id );
            _check_notify_ok( $reservs[4], $operator->id, $stock_manager->_emails->[0]->{email_params} );

            # check sending emails using the 'commit' method works
            $stock_manager->commit;
            _check_emails_sent_ok( $stock_manager, 'commit', \$emails_sent, \@email_addresses, [ $reservs[4] ] );

            note "checking if problem with email doesn't crash everything else";
            $email_die  = 1;
            $stock_manager->stock_update( %stock_args, quantity_change => 2 );
            $prev_log   = _check_reservation_ok( $reservs[5]->discard_changes, $prev_log->balance + 1 );
            $prev_log   = _check_reservation_ok( $reservs[6]->discard_changes, $prev_log->balance + 1 );
            lives_ok( sub {
                    $stock_manager->commit;
                }, "'commit' lives even though 'send_email' died" );
            cmp_ok( $emails_died, '==', 2, "Email Died Counter set to 2 - therefore if 1 dies it still tries more" );
            $emails_died    = 0;


            note "checking 'disconnect' & 'rollback' both clear the Stock Manager Emails";

            $stock_manager->stock_update( %stock_args );
            $prev_log   = _check_reservation_ok( $reservs[7]->discard_changes, $prev_log->balance + 1 );
            cmp_ok( @{ $stock_manager->_emails }, '==', 1, "There is 1 Email in the Array prior to 'Rollback'" );
            $stock_manager->rollback;
            cmp_ok( @{ $stock_manager->_emails }, '==', 0, "There is ZERO Email in the Array after 'Rollback'" );

            $stock_manager->stock_update( %stock_args );
            $prev_log   = _check_reservation_ok( $reservs[8]->discard_changes, $prev_log->balance + 1 );
            cmp_ok( @{ $stock_manager->_emails }, '==', 1, "There is 1 Email in the Array prior to 'Disconnect'" );
            $stock_manager->disconnect;
            cmp_ok( @{ $stock_manager->_emails }, '==', 0, "There is ZERO Email in the Array after 'Disconnect'" );


            note "get a new Stock Manager, call Stock Update, Commit, Disconnect WITH 3 Pending Reservations to Upload";

            # zero out counters for 'send_email'
            $email_die      = 0;        # make sure 'send_email' doesn't die
            $emails_died    = 0;
            $emails_sent    = 0;
            @email_addresses= ();

            # get a new instance of the Stock Manager with the send_email function still overridden
            $stock_manager  = XTracker::WebContent::StockManagement->new_stock_manager( {
                                                                schema      => $schema,
                                                                channel_id  => $channel->id,
                                                        } );
            $stock_args{quantity_change}    = 3;
            lives_ok( sub {
                    $stock_manager->stock_update( %stock_args );
                    $stock_manager->commit;
                    $stock_manager->disconnect;
                }, "Stock Update, Commit, Disconnect OK" );

            foreach my $reserv ( @reservs[ 9..11 ] ) {
                $prev_log   = _check_reservation_ok( $reserv->discard_changes, $prev_log->balance + 1 );
            }
            cmp_ok( $emails_died, '==', 0, "Emails Died: 0" );
            _check_emails_sent_ok( $stock_manager, 'the lifecycle', \$emails_sent, \@email_addresses, [ @reservs[ 9..11 ] ] );

            note "get a new Stock Manager, call Stock Update, Commit, Disconnect with ZERO Pending Reservations to Upload";

            # get a new instance of the Stock Manager with the send_email function still overridden
            $stock_manager  = XTracker::WebContent::StockManagement->new_stock_manager( {
                                                                schema      => $schema,
                                                                channel_id  => $channel->id,
                                                        } );
            lives_ok( sub {
                    $stock_manager->stock_update( %stock_args );
                    $stock_manager->commit;
                    $stock_manager->disconnect;
                }, "Stock Update, Commit, Disconnect OK" );
            cmp_ok( $emails_died, '==', 0, "Emails Died: 0" );
            cmp_ok( $emails_sent, '==', 0, "Emails Sent: 0" );
            cmp_ok( $reserv_max_log->max(), '==', $prev_log->id, "No new Reservation Logs Created" );


            note "get a new Stock Manager and now test that when XT or Web Stock Levels are a bit off ONLY Upload if there REALLY IS Enough Stock";
            $stock_manager  = XTracker::WebContent::StockManagement->new_stock_manager( {
                                                                schema      => $schema,
                                                                channel_id  => $channel->id,
                                                        } );

            # get XT Stock Quantity record
            $variant->quantities->update( { quantity => 0 } );      # clear down existing stock
            my $xt_stock    = $variant->quantities->search( { channel_id => $channel->id, status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS } )->first;

            $web_stock_level= 10;       # set web-site stock level

            # set all the previous reservations to be purchased and
            # out of the way of the new ones that will be created
            foreach my $reserv ( @reservs ) {
                $reserv->update( { status_id => $RESERVATION_STATUS__PURCHASED, ordering_id => 0 } );
            }

            # create some new reservations
            @reservs    = _create_reservations( 10, $channel, $variant, $operator );

            # set-up the args used by the 'stock_update' method
            %stock_args = (
                quantity_change => 1,
                variant_id      => $variant->id,
                pws_action_id   => $PWS_ACTION__ORDER,
            );

            note "check using 'stock_update' with ZERO XT Stock then no Upload happens";
            $stock_manager->stock_update( %stock_args );
            foreach my $reserv ( @reservs ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            note "check using 'stock_update' with ZERO Web Stock then no Upload happens";
            $web_stock_level    = 0;
            $xt_stock->update( { quantity => 100 } );
            $stock_manager->stock_update( %stock_args );
            foreach my $reserv ( @reservs ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            note "check using 'stock_update' with 1 Web Stock & XT Stock then One Upload happens";
            $web_stock_level    = 1;
            $xt_stock->update( { quantity => 1 } );
            $stock_manager->stock_update( %stock_args );
            $prev_log   = _check_reservation_ok( $reservs[0]->discard_changes, 1 );
            foreach my $reserv ( @reservs[ 1..$#reservs ] ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            note "check using 'stock_update' with Qty Change of 3 but with 1 Web Stock & XT Stock then Only One Upload happens";
            $xt_stock->update( { quantity => 2 } );     # set to 2 because the previous reservation will be taken off
            $stock_args{quantity_change}    = 3;
            $stock_manager->stock_update( %stock_args );
            $prev_log   = _check_reservation_ok( $reservs[1]->discard_changes, $prev_log->balance + 1 );
            foreach my $reserv ( @reservs[ 2..$#reservs ] ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            note "check using 'stock_update' with Qty Change of 3 but with 2 Web Stock & 1 XT Stock then Only One Upload happens";
            $web_stock_level    = 2;
            $xt_stock->update( { quantity => 3 } );     # set to 3 because the previous reservations will be taken off
            $stock_manager->stock_update( %stock_args );
            $prev_log   = _check_reservation_ok( $reservs[2]->discard_changes, $prev_log->balance + 1 );
            foreach my $reserv ( @reservs[ 3..$#reservs ] ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            note "check using 'stock_update' with Qty Change of 3 but with 1 Web Stock & 2 XT Stock then Only One Upload happens";
            $web_stock_level    = 1;
            $xt_stock->update( { quantity => 5 } );     # set to 3 because the previous reservations will be taken off
            $stock_manager->stock_update( %stock_args );
            $prev_log   = _check_reservation_ok( $reservs[3]->discard_changes, $prev_log->balance + 1 );
            foreach my $reserv ( @reservs[ 4..$#reservs ] ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            note "check using 'stock_update' with Qty Change of 1 but with 1 Web Stock & -1 XT Stock then NO Upload happens";
            $stock_args{quantity_change}    = 1;
            $web_stock_level    = 1;
            $xt_stock->update( { quantity => 3 } );     # set to 3 because the previous reservations will be taken off equaling -1
            $stock_manager->stock_update( %stock_args );
            foreach my $reserv ( @reservs[ 4..$#reservs ] ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            note "check using 'stock_update' with Qty Change of 1 but with -1 Web Stock & 1 XT Stock then NO Upload happens";
            $web_stock_level    = -1;
            $xt_stock->update( { quantity => 5 } );     # set to 3 because the previous reservations will be taken off equaling -1
            $stock_manager->stock_update( %stock_args );
            foreach my $reserv ( @reservs[ 4..$#reservs ] ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            note "check using 'stock_update' with Qty Change of 3 but with 3 Web Stock & 2 XT Stock then 2 Uploads happen";
            $stock_args{quantity_change}    = 3;
            $web_stock_level    = 3;
            $xt_stock->update( { quantity => 6 } );     # set to 6 because the previous reservations will be taken off
            $stock_manager->stock_update( %stock_args );
            $prev_log   = _check_reservation_ok( $reservs[4]->discard_changes, $prev_log->balance + 1 );
            $prev_log   = _check_reservation_ok( $reservs[5]->discard_changes, $prev_log->balance + 1 );
            foreach my $reserv ( @reservs[ 6..$#reservs ] ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            note "check using 'stock_update' with Qty Change of 3 but with 2 Web Stock & 3 XT Stock then 2 Uploads happen";
            $web_stock_level    = 2;
            $xt_stock->update( { quantity => 9 } );     # set to 9 because the previous reservations will be taken off
            $stock_manager->stock_update( %stock_args );
            $prev_log   = _check_reservation_ok( $reservs[6]->discard_changes, $prev_log->balance + 1 );
            $prev_log   = _check_reservation_ok( $reservs[7]->discard_changes, $prev_log->balance + 1 );
            foreach my $reserv ( @reservs[ 8..$#reservs ] ) {
                cmp_ok( $reserv->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$reserv->id. " still Pending" );
            }

            note "check using 'stock_update' with Qty Change of 3 but with 2 Web Stock & 2 XT Stock then 2 Uploads happen";
            $web_stock_level    = 2;
            $xt_stock->update( { quantity => 10 } );     # set to 11 because the previous reservations will be taken off
            $stock_manager->stock_update( %stock_args );
            $prev_log   = _check_reservation_ok( $reservs[8]->discard_changes, $prev_log->balance + 1 );
            $prev_log   = _check_reservation_ok( $reservs[9]->discard_changes, $prev_log->balance + 1 );


            # rollback changes
            $schema->txn_rollback;
        } );
    };

    return;
}

# this will test that Pre-Order Reservations can be
# Uploaded correctly, via the Product Upload process
# or via Auto-Upload when a Stock Adjustment is done
sub _test_uploading_pre_order_reservations {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_uploading_pre_order_reservations", 1        if ( !$oktodo );

        note "TESTING: Uploading Pre-Order Reservations";

        my $operator    = Test::XTracker::Data->_get_operator( $APPLICATION_OPERATOR_ID );

        # overload 'get_web_stock_level' to always return 100
        my $web_stock_level = 100;
        no warnings 'redefine';
        *XTracker::WebContent::StockManagement::OurChannels::get_web_stock_level   = sub { return $web_stock_level; };
        use warnings 'redefine';

        $schema->txn_do( sub {
            my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
                                                                how_many => 1,
                                                                channel => Test::XTracker::Data->channel_for_nap,
                                                                ensure_stock_all_variants => 1,
                                                            } );
            my $variant     = $pids->[0]{variant};
            my $prod_chann  = _clean_up_system_for_variant( $variant, $channel );

            my $stock_manager   = XTracker::WebContent::StockManagement->new_stock_manager( {
                                                                schema      => $schema,
                                                                channel_id  => $channel->id,
                                                        } );
            # this is used in mocking the Web DB
            my $web_dbh = $stock_manager->_web_dbh;

            my @reservations            = _create_reservations( 3, $channel, $variant, $operator );
            # make the second Reservation for the same Customer and SKU as the first
            $reservations[1]->update( { customer_id => $reservations[0]->customer->id } );

            my @pre_order_reservations  = Test::XTracker::Data::PreOrder->create_pre_order_reservations( { variants => [ $variant ] } )->[0];
            # create a Pre-Order Reservation for the same SKU and Customer as the one above
            push @pre_order_reservations, Test::XTracker::Data::PreOrder->create_pre_order_reservations( { variants => [ $variant ] } )->[0];
            $pre_order_reservations[1]->update( { customer_id => $pre_order_reservations[0]->customer_id } );

            # this is the SQL statement sent to the Web that should be mocked
            my $sql_to_mock     = "SELECT reserved_quantity FROM simple_reservation WHERE customer_id = ? AND sku = ?";
            my $results_to_mock = [ [ 'reserved_quantity' ], [ 1 ] ];

            # used when updating records as part of the Product Upload
            # process to say what performed the action
            my $audit_application   = 'XTRACKER';

            my @tests = (
                {
                    label   => 'Upload Pre-Order Reservation - should INSERT to the Web',
                    reservation_uploaded => $pre_order_reservations[0],
                    send_alerts     => 0,       # Pre-Order Reservations shouldn't be sent Alerts
                    sql_sent_to_web => {
                        statement   => qr/INSERT.*simple_reservation.*\(\s*\?,\s*\?,\s*1,\s*1,\s*current_timestamp.*/si,
                    },
                    stock_adjust_data   => {
                        bound_params=> [
                            $pre_order_reservations[0]->customer->is_customer_number,
                            $pre_order_reservations[0]->variant->sku,
                        ],
                    },
                    product_upload_data => {
                        mock_resultset  => [
                            [ [ 'no_in_stock' ], [ 4 ] ],           # give the Stock Level
                            [ [ 'reserved_quantity' ], ],           # Simple Reservation Record Exists Check, so it fails
                            [ [ 'rows' ], [ 1 ] ],                  # INSERT should return 1 Row
                            [ [ 'reserved_quantity' ], [ 1 ] ],     # Simple Reservation Qry returns a result for Updating Expiry Date
                            [ [ 'rows' ], [ 1 ] ],                  # UPDATE Expiry Date affected 1 Row
                            [ [ 'rows' ], [ 1 ] ],                  # UPDATE Stock Location affected 1 Row
                        ],
                        bound_params=> [
                            $pre_order_reservations[0]->customer->is_customer_number,
                            $pre_order_reservations[0]->variant->sku,
                        ],
                    },
                },
                {
                    label   => 'Upload Pre-Order Reservation - should UPDATE to the Web',
                    reservation_uploaded => $pre_order_reservations[1],
                    send_alerts     => 0,       # Pre-Order Reservations shouldn't be sent Alerts
                    sql_sent_to_web => {
                        statement   => qr/
                            UPDATE.*simple_reservation.*
                                SET\s*reserved_quantity\s=\sreserved_quantity\s\+\s1\s*,.*
                                    redeemed_quantity\s=\sredeemed_quantity\s\+\s1\s*,.*
                            WHERE.*
                        /xsi,
                    },
                    stock_adjust_data    => {
                        mock_resultset  => {
                            sql     => $sql_to_mock,
                            results => $results_to_mock,
                        },
                        bound_params=> [
                            $pre_order_reservations[0]->customer->is_customer_number,
                            $pre_order_reservations[0]->variant->sku,
                        ],
                    },
                    product_upload_data => {
                        mock_resultset  => [
                            [ [ 'no_in_stock' ], [ 3 ] ],               # give the Stock Level
                            [ [ 'reserved_quantity' ], [ 1 ] ],         # Simple Reservation Record Exists Check, just any data will do
                            [ [ 'rows' ], [ 1 ] ],                      # UPDATE should return 1 Row
                            [ [ 'reserved_quantity' ], [ 1 ] ],         # Simple Reservation Qry returns a result for Updating Expiry Date
                            [ [ 'rows' ], [ 1 ] ],                      # UPDATE Expiry Date affected 1 Row
                            [ [ 'rows' ], [ 1 ] ],                      # UPDATE Stock Location affected 1 Row
                        ],
                        bound_params=> [
                            $pre_order_reservations[0]->customer->is_customer_number,
                            $pre_order_reservations[0]->variant->sku,
                        ],
                    },
                },
                {
                    label   => 'Upload Normal Reservation - should INSERT to the Web',
                    reservation_uploaded => $reservations[0],
                    send_alerts     => 1,       # Normal Reservations should be sent Alerts
                    sql_sent_to_web => {
                        statement   => qr/INSERT.*simple_reservation.*\(\s*\?,\s*\?,\s*1,\s*0,\s*current_timestamp.*/si,
                    },
                    stock_adjust_data   => {
                        bound_params=> [
                            $reservations[0]->customer->is_customer_number,
                            $reservations[0]->variant->sku,
                        ],
                    },
                    product_upload_data => {
                        mock_resultset  => [
                            [ [ 'no_in_stock' ], [ 2 ] ],           # give the Stock Level
                            [ [ 'reserved_quantity' ], ],           # Simple Reservation Qry returns a result for Updating Expiry Date
                            [ [ 'rows' ], [ 1 ] ],                  # INSERT should return 1 Row
                            [ [ 'reserved_quantity' ], [ 1 ] ],     # Simple Reservation Qry returns a result for Updating Expiry Date
                            [ [ 'rows' ], [ 1 ] ],                  # UPDATE Expiry Date affected 1 Row
                            [ [ 'rows' ], [ 1 ] ],                  # UPDATE Stock Location affected 1 Row
                        ],
                        bound_params=> [
                            $reservations[0]->customer->is_customer_number,
                            $reservations[0]->variant->sku,
                        ],
                    },
                },
                {
                    label   => 'Upload Normal Reservation - should UPDATE to the Web',
                    reservation_uploaded => $reservations[1],
                    send_alerts     => 1,       # Normal Reservations should be sent Alerts
                    sql_sent_to_web => {
                        statement   => qr/
                            UPDATE\s*simple_reservation\s*
                                SET\s*reserved_quantity\s=\sreserved_quantity\s\+\s1\s*,\s*
                                    status\s=\s'PENDING'
                                    (\s*,\s*last_updated_by\s=\s'XTRACKER'\s*)?\s*
                            WHERE.*
                        /xsi,
                    },
                    stock_adjust_data    => {
                        mock_resultset  => {
                            sql     => $sql_to_mock,
                            results => $results_to_mock,
                        },
                        bound_params=> [
                            $reservations[1]->customer->is_customer_number,
                            $reservations[1]->variant->sku,
                        ],
                    },
                    product_upload_data => {
                        mock_resultset  => [
                            [ [ 'no_in_stock' ], [ 1 ] ],               # give the Stock Level
                            [ [ 'reserved_quantity' ], [ 1 ] ],         # Simple Reservation Qry returns a result for Updating Expiry Date
                            [ [ 'rows' ], [ 1 ] ],                      # UPDATE should return 1 Row
                            [ [ 'reserved_quantity' ], [ 1 ] ],         # Simple Reservation Qry returns a result for Updating Expiry Date
                            [ [ 'rows' ], [ 1 ] ],                      # UPDATE Expiry Date affected 1 Row
                            [ [ 'rows' ], [ 1 ] ],                      # UPDATE Stock Location affected 1 Row
                        ],
                        bound_params=> [
                            $reservations[1]->customer->is_customer_number,
                            $reservations[1]->variant->sku,
                        ],
                    },
                },
            );

            note "Uploading when Stock is Adjusted";

            my %stock_upd_args = (
                quantity_change => 1,
                variant_id      => $variant->id,
                pws_action_id   => $PWS_ACTION__ORDER,
            );

            foreach my $test ( @tests ) {
                my $label   = $test->{label};
                my $data    = $test->{stock_adjust_data};

                note "TESTING: $label";

                $web_dbh->{mock_clear_history}  = 1;
                if ( $data->{mock_resultset} ) {
                    $web_dbh->{mock_add_resultset}  = $data->{mock_resultset};
                }

                # Reservations for Pre-Orders shouldn't be sent
                # Emails or their Operators Alerted
                my $operator    = $test->{reservation_uploaded}->operator;
                $operator->discard_changes->sent_messages->delete;
                $operator->received_messages->delete;

                $stock_manager->stock_update( %stock_upd_args );
                my $reservation = $test->{reservation_uploaded}->discard_changes;
                my $sql_to_chk  = $test->{sql_sent_to_web};

                cmp_ok( $reservation->status_id, '==', $RESERVATION_STATUS__UPLOADED, "Reservation has been Uploaded" );

                $operator->discard_changes;
                if ( $test->{send_alerts} ) {
                    cmp_ok( $operator->received_messages->count(), '==', 1, "Alert Message Sent to Operator: " . $operator->name );
                    cmp_ok( $reservation->notified, '==', 1, "Customer Notified" );
                }
                else {
                    cmp_ok( $operator->received_messages->count(), '==', 0, "NO Alert Message Sent to Operator: " . $operator->name );
                    cmp_ok( $reservation->notified, '==', 0, "Customer NOT Notified" );
                }

                # check the SQL statement that was sent to the Web to create
                # the Reservation, it should have been the 4th statement sent
                my $statement   = $web_dbh->{mock_all_history}->[3];
                if ( $statement ) {
                    like( $statement->statement, $sql_to_chk->{statement},
                                                "SQL Statement used to create Web Reservation as Expected:\n" . $statement->statement );
                    is_deeply( $statement->bound_params, $data->{bound_params}, "The Bound Parameters for the Statement as Expected" );
                }
                else {
                    fail("There was NO 4th Statement sent to the Web");
                }

                # clear out the resulset for the next test
                if ( $data->{mock_resultset} ) {
                    $web_dbh->{mock_add_resultset}  = {
                                                    sql     => $data->{mock_resultset}{sql},
                                                    results => [],
                                                };
                }
            }
            cmp_ok( $reservations[2]->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING,
                                            "The Final Reservation created is still 'Pending'" );


            note "Uploading when Product is put Live - Product Upload process";
            # reset all the Reservations to be 'Pending'
            foreach my $reservation ( ( @reservations, @pre_order_reservations ) ) {
                $reservation->discard_changes;
                $reservation->reservation_logs->delete;
                $reservation->update( { status_id => $RESERVATION_STATUS__PENDING } );
            }

            # Totally re-set the resultset otherwise we seem to end up
            # with stray named SQL queries that take precedence over the
            # ordered resultset data
            $web_dbh->{mock_rs} = {};

            # set-up the Result Sets returned by the Mock Web DBH
            foreach my $test ( @tests ) {
                my $data    = $test->{product_upload_data};
                foreach my $rs ( @{ $data->{mock_resultset} } ) {
                    $web_dbh->{mock_add_resultset}  = $rs;
                }
            }
            # make sure for the last Reservation there's not enough stock
            $web_dbh->{mock_add_resultset}  = [ [ 'no_in_stock' ], [ 0 ] ];

            # upload all Reservations for the Variant in one go
            $web_dbh->{mock_clear_history}  = 1;
            transfer_product_reservations( {
                dbh_ref => {
                    sink_environment    => 'live',
                    sink_site           => lc( config_var('XTracker','instance') ),
                    dbh_source          => $schema->storage->dbh,
                    dbh_sink            => $web_dbh,
                },
                channel_id      => $channel->id,
                product_ids     => $variant->product_id,
                stock_manager   => $stock_manager,
            } );

            # now test the results
            my $statements  = $web_dbh->{mock_all_history};
            my $no_statements_per_upload    = 6;        # number of statements sent to the Web for each Reservation Upload
            my $pos_of_create_statement     = 2;        # position of the Create Reservation statement in each upload (zero based)

            foreach my $loop ( 0..$#tests ) {
                my $label   = $tests[ $loop ]->{label};
                my $data    = $tests[ $loop ]->{product_upload_data};

                note "TESTING: $label";

                my $reservation = $tests[ $loop ]->{reservation_uploaded}->discard_changes;
                my $sql_to_chk  = $tests[ $loop ]->{sql_sent_to_web};

                # check the SQL statement that was sent to the Web to create
                # the Reservation, it should have been the 4th statement sent
                my $idx = ( ( $loop * $no_statements_per_upload ) + $pos_of_create_statement );
                my $statement   = $statements->[ $idx ];
                if ( $statement ) {
                    like( $statement->statement, $sql_to_chk->{statement},
                                                "SQL Statement used to create Web Reservation as Expected:\n" . $statement->statement );
                    is_deeply( $statement->bound_params, $data->{bound_params}, "The Bound Parameters for the Statement as Expected" );
                }
                else {
                    fail("There was NO Create Statement sent to the Web at IDX: $idx");
                }
            }
            cmp_ok( $reservations[2]->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING,
                                            "The Final Reservation created is still 'Pending'" );


            # rollback changes
            $schema->txn_rollback;
        } );
    };

    return;
}

# test when Cancelling a Reservation for
# Normal Reservations and Pre-Orders that
# the frontend is updated correctly
sub _test_cancelling_pre_order_reservations {
    my ( $schema, $oktodo ) = @_;

    # get the DBH handle from Schema
    my $dbh = $schema->storage->dbh;

    SKIP: {
        skip "_test_cancelling_pre_order_reservations", 1        if ( !$oktodo );

        note "TESTING: Cancelling Pre-Order Reservations";

        my $operator = Test::XTracker::Data->get_application_operator();

        $schema->txn_do( sub {
            my ( $channel, $pids ) = Test::XTracker::Data->grab_products( {
                how_many => 1,
                channel  => Test::XTracker::Data->channel_for_nap,
                ensure_stock_all_variants => 1,
            } );
            my $variant    = $pids->[0]{variant};
            my $prod_chann = _clean_up_system_for_variant( $variant, $channel );

            my $stock_manager = XTracker::WebContent::StockManagement->new_stock_manager( {
                schema     => $schema,
                channel_id => $channel->id,
            } );
            # this is used in mocking the Web DB
            my $web_dbh = $stock_manager->_web_dbh;

            my @reservations = _create_reservations( 3, $channel, $variant, $operator );
            # make the second Reservation for the same Customer as the first
            $reservations[1]->update( { customer_id => $reservations[0]->customer->id } );

            my @pre_order_reservations = Test::XTracker::Data::PreOrder->create_pre_order_reservations( { variants => [ $variant ] } )->[0];
            # create a Pre-Order Reservation for the same SKU and Customer as the one above
            push @pre_order_reservations, Test::XTracker::Data::PreOrder->create_pre_order_reservations( { variants => [ $variant ] } )->[0];
            $pre_order_reservations[1]->update( { customer_id => $pre_order_reservations[0]->customer_id } );

            # this is the SQL statement sent to the Web that should be mocked
            my $sql_to_mock     = "SELECT reserved_quantity FROM simple_reservation WHERE customer_id = ? AND sku = ?";
            my $results_to_mock = [ [ 'reserved_quantity' ], [ 1 ] ];

            my @tests = (
                {
                    label           => 'Cancel Uploaded Pre-Order Reservation - Should Update Web',
                    reservation     => $pre_order_reservations[0],
                    set_status      => $RESERVATION_STATUS__UPLOADED,
                    sql_sent_to_web => {
                        statement   => qr/
                            UPDATE\s*simple_reservation\s*
                                SET\s*reserved_quantity\s=\sreserved_quantity\s\-\s1\s*,.*
                                    redeemed_quantity\s=\sredeemed_quantity\s\-\s1\s*
                            WHERE.*
                            AND\sreserved_quantity\s>\s0
                        /xsi,
                    },
                    data => {
                        mock_resultset  => {
                            sql     => $sql_to_mock,
                            results => $results_to_mock,
                        },
                        bound_params=> [
                            $pre_order_reservations[0]->customer->is_customer_number,
                            $pre_order_reservations[0]->variant->sku,
                        ],
                    },
                },
                {
                    label           => 'Cancel Non-Uploaded Pre-Order Reservation - Should NOT Update Web',
                    reservation     => $pre_order_reservations[1],
                    set_status      => $RESERVATION_STATUS__PENDING,
                    sql_sent_to_web => undef,
                },
                {
                    label           => 'Cancel Uploaded Normal Reservation - Should Update Web',
                    reservation     => $reservations[0],
                    set_status      => $RESERVATION_STATUS__UPLOADED,
                    sql_sent_to_web => {
                        statement   => qr/
                            UPDATE\s*simple_reservation\s*
                                SET\s*reserved_quantity\s=\sreserved_quantity\s\-\s1\s*
                            WHERE.*
                            AND\sreserved_quantity\s>\s0
                        /xsi,
                    },
                    data => {
                        mock_resultset  => {
                            sql     => $sql_to_mock,
                            results => $results_to_mock,
                        },
                        bound_params=> [
                            $reservations[0]->customer->is_customer_number,
                            $reservations[0]->variant->sku,
                        ],
                    },
                },
                {
                    label           => 'Cancel Non-Uploaded Normal Reservation - Should NOT Update Web',
                    reservation     => $reservations[1],
                    set_status      => $RESERVATION_STATUS__PENDING,
                    sql_sent_to_web => undef,
                },
            );

            foreach my $test ( @tests ) {
                my $label   = $test->{label};
                my $data    = $test->{data};

                note "TESTING: $label";

                # get the Reservation and Update the Status if required
                my $reservation = $test->{reservation}->discard_changes;
                if ( my $status_id = $test->{set_status} ) {
                    $reservation->update( { status_id => $status_id } );
                }

                $web_dbh->{mock_clear_history} = 1;
                if ( $data->{mock_resultset} ) {
                    $web_dbh->{mock_add_resultset} = $data->{mock_resultset};
                }

                # Cancel the Reservation
                cancel_reservation( $dbh, $stock_manager, {
                    reservation_id  => $reservation->id,
                    variant_id      => $reservation->variant_id,
                    status_id       => $reservation->status_id,
                    customer_nr     => $reservation->customer->is_customer_number,
                    operator_id     => $operator->id,
                } );

                # check the Reservation's Status
                cmp_ok( $reservation->discard_changes->status_id, '==', $RESERVATION_STATUS__CANCELLED,
                                                "Reservation has been Cancelled" );

                # if expected check the SQL statement sent to
                # the Web to make sure it is the Correct one
                if ( my $expect_sql = $test->{sql_sent_to_web} ) {
                    # check the SQL statement that was sent to the Web to Update
                    # the Reservation, it should have been the 3rd statement sent
                    my $statement  = $web_dbh->{mock_all_history}->[2];
                    my $sql_to_chk = $test->{sql_sent_to_web};
                    like( $statement->statement, $sql_to_chk->{statement},
                                        "SQL Statement used to Update the Web Reservation as Expected:\n" . $statement->statement );
                    is_deeply( $statement->bound_params, $data->{bound_params},
                                        "The Bound Parameters for the Statement as Expected" );
                }
                else {
                    my @statements = @{ $web_dbh->{mock_all_history} };
                    cmp_ok( scalar( @statements ), '==', 1, "Only one SQL statement sent to the Web" )
                                        or diag "TEST FAILED - More than One SQL Statement: " . p( @statements );
                    unlike( $statements[0], qr/UPDATE/i, "but is NOT an UPDATE statement" );
                }

                # clear out the resulset for the next test
                if ( $data->{mock_resultset} ) {
                    $web_dbh->{mock_add_resultset}  = {
                        sql     => $data->{mock_resultset}{sql},
                        results => [],
                    };
                }
            }

            # rollback changes
            $schema->txn_rollback;
        } );
    };

    return;
}

#----------------------------------------------------------------------

# helper to call the 'XTracker::Comms::DataTransfer::list_reservations'
# and then to filter the results for only the Variant we care about
sub _call_list_reservations {
    my ( $variant, $func_args )     = @_;

    my @retval;

    my $array_ref   = list_reservations( $func_args );
    foreach my $row ( @{ $array_ref } ) {
        push @retval, $row          if ( $row->{variant_id} == $variant->id );
    }

    return @retval;
}

# helper to create X number of reservations
sub _create_reservations {
    my ( $number, $channel, $variant, $operator )   = @_;

    my @reservations;

    foreach my $counter ( 1..$number ) {
        my $data = Test::XT::Data->new_with_traits(
                        traits => [
                            'Test::XT::Data::ReservationSimple',
                        ],
                    );

        $data->operator( $operator );
        $data->channel( $channel );
        $data->variant( $variant );                             # make sure all reservations are for the same SKU

        my $reservation = $data->reservation;
        $reservation->update( { ordering_id => $counter } );    # prioritise each reservation

        # make sure the Customer has a different Email
        # Address than every other Reservation's Customer
        $reservation->customer->update( { email => $reservation->customer->is_customer_number . '.test@net-a-porter.com' } );
        # set the Customer's Language as 'French' so as
        # to require a Localised From Address for emails
        $reservation->customer->set_language_preference('fr');
        note "Customer Id/Nr: ".$reservation->customer->id."/".$reservation->customer->is_customer_number;

        push @reservations, $reservation;
    }

    return @reservations;
}

# helper to check the Reservation after it's been uploaded
# such as logs and upload dates etc.
sub _check_reservation_ok {
    my ( $reservation, $balance, $operator_id )     = @_;

    note "Checking Reservation: " . $reservation->id;

    $operator_id    ||= $APPLICATION_OPERATOR_ID;

    my $log = $reservation->reservation_logs
                            ->search( {}, { order_by => 'id DESC' } )->first;

    cmp_ok( $reservation->status_id, '==', $RESERVATION_STATUS__UPLOADED, "Reservation Status it'self is 'Uploaded'" );
    isa_ok( $reservation->date_uploaded, 'DateTime', "Date Uploaded now has a value" );
    my $expiry  = $reservation->date_uploaded->clone->add( days => 1 )->set( hour => 23, minute => 59, second => 59, nanosecond => 0 );
    cmp_ok( DateTime->compare( $reservation->date_expired, $expiry ), '==', 0, "Expiry Date is Now + 1 Day" );

    cmp_ok( $log->reservation_status_id, '==', $RESERVATION_STATUS__UPLOADED, "Log Status is 'Uploaded'" );
    cmp_ok( $log->operator_id, '==', $operator_id, "Log Operator is as Expected: $operator_id" );
    cmp_ok( $log->quantity, '==', 1, "Log Quantity is '1'" );
    cmp_ok( $log->balance, '==', $balance, "Log Balance as expected: $balance" );

    return $log;
}

# helper to make sure the notification was done correctly
sub _check_notify_ok {
    my ( $reservation, $operator_id, $email_params )    = @_;

    note "Checking Notification for Reservation: " . $reservation->id;

    my $sku     = $reservation->variant->sku;
    my $pid     = $reservation->variant->product_id;
    my $customer= $reservation->customer;
    my $cust_nr = $customer->is_customer_number;
    my $name    = $customer->first_name;

    my $from_email  = get_from_email_address( {
        channel_config  => $reservation->channel->business->config_section,
        department_id   => $reservation->operator->department_id,
        schema          => $reservation->result_source->schema,
        locale          => $reservation->customer->locale,
    } );

    cmp_ok( $reservation->notified, '==', 1, "Reservation 'notified' flag is now TRUE" );

    my $message = $reservation->operator
                        ->received_messages->search(
                                        {
                                            subject => { ilike => 'Customer Reservation: %'.$cust_nr.'%'.$sku.'% Uploaded' },
                                        },
                                        {
                                            order_by => 'id DESC'
                                        } )->first;
    isa_ok( $message, 'XTracker::Schema::Result::Operator::Message', "Message created for Reservation's Operator" );
    is( $message->subject, "Customer Reservation: $cust_nr for $sku has been Uploaded",
                        "Operator Message Subject as Expected" );
    like( $message->body, qr{Customer: $cust_nr.*Reserved item: $sku .*Has now been uploaded},
                        "Operator Message Body as Expected" );
    cmp_ok( $message->sender_id, '==', $operator_id, "Operator Message Sent By as Expected: ".$operator_id );

    cmp_ok( keys %{ $email_params }, '==', 6, "Got 6 Parameters for 'send_email' function" );
    is( $email_params->{from}, $from_email, "From Email Address as Expected" );
    is( $email_params->{reply_to}, $email_params->{from}, "Reply To Email Address same as From Address" );
    is( $email_params->{to}, $customer->email, "To Email Address is the Customers" );
    like( $email_params->{subject}, qr/\w+/, "Email Subject has content" );
    like( $email_params->{content}, qr{$name.*$pid}s, "Email Body has Customer Name & PID in it" );
    is( $email_params->{content_type}, 'html', "Email Type is 'html'" );

    return;
}

# helper to check the Customer Resevation emails got sent OK
sub _check_emails_sent_ok {
    my ( $stock_manager, $method, $counter, $addresses, $reservations ) = @_;

    note "checking Customer Reservation Emails sent using method: $method";

    cmp_ok( $$counter, '==', @{ $reservations }, "Expected number of Emails sent: ".@{ $reservations } );

    # check the Email To Addresses
    while ( my $reservation = shift @{ $reservations } ) {
        my $to = shift @{ $addresses };
        is( $reservation->customer->email, $to, "Reservation: ".$reservation->id.", Customer's Email Addresses matches what was Sent: $to" );
    }

    cmp_ok( @{ $stock_manager->_emails }, '==', 0, "There are NO emails any more in the Stock Manager Object" );

    @{ $addresses } = ();
    $$counter       = 0;

    return;
}

# checks the '_get_true_qty_change' method to make sure
# the correct values are returned
sub _check__get_true_qty_change__method {
    my $stock_manager   = shift;

    note "checking '_get_true_qty_change' method";

    # check passing 'undefs' in
    my $value   = $stock_manager->_get_true_qty_change();
    ok( defined $value && $value == 0, "when passing in 'undefs' get zero back" );

    my %tests   = (
            "when Web Stock Level is lowest returns lowest value of 2" => {
                qty_change => 100, xt_level => 3, web_level => 2, expected => 2
            },
            "when XT Stock Level is lowest returns lowest value of 2" => {
                qty_change => 100, xt_level => 2, web_level => 3, expected => 2
            },
            "when XT Stock Level and Web Stock Level are equal returns lowest value of 2" => {
                qty_change => 100, xt_level => 2, web_level => 2, expected => 2
            },
            "when XT Stock Level is Zero get Zero Back" => {
                qty_change => 100, xt_level => 0, web_level => 2, expected => 0
            },
            "when Web Stock Level is Zero get Zero Back" => {
                qty_change => 100, xt_level => 2, web_level => 0, expected => 0
            },
            "when Both Web Stock Level & XT Stock Level are Zero get Zero Back" => {
                qty_change => 100, xt_level => 0, web_level => 0, expected => 0
            },
            "when XT Stock Level is '-1' then return Zero" => {
                qty_change => 100, xt_level => -1, web_level => 2, expected => 0
            },
            "when Web Stock Level is '-1' then return Zero" => {
                qty_change => 100, xt_level => 2, web_level => -1, expected => 0
            },
            "when Web Stock Level is lowest (3) but greater than Qty Change (2) then get Qty Change figure back (2)" => {
                qty_change => 2, xt_level => 5, web_level => 3, expected => 2
            },
            "when XT Stock Level is lowest (3) but greater than Qty Change (2) then get Qty Change figure back (2)" => {
                qty_change => 2, xt_level => 3, web_level => 5, expected => 2
            },
            "when Qty Change is '-1' and everything else is positive get '-1' back" => {
                qty_change => -1, xt_level => 3, web_level => 5, expected => -1
            },
            "when Qty Change is '-1' and everything else is '-2' get Qty Change value (-1) back" => {
                qty_change => -1, xt_level => -2, web_level => -2, expected => -1
            },
            "(Most Likely Real World Scenario) when Qty Change is '1' and XT Stock Level is '-1' and Web Stock Level is '1' then get Zero back" => {
                qty_change => 1, xt_level => -1, web_level => 1, expected => 0
            },
        );

    foreach my $test_label ( sort keys %tests ) {
        my $test    = $tests{ $test_label };
        cmp_ok( $stock_manager->_get_true_qty_change( $test->{qty_change}, $test->{xt_level}, $test->{web_level} ), '==', $test->{expected}, $test_label );
    }

    return;
}

# turns on & off the 'Automatic_Reservation_Upload_Upon_Stock_Updates' config for a Channel
sub _switch_auto_upload_config {
    my ( $channel, $switch )    = @_;

    Test::XTracker::Data->remove_config_group( 'Automatic_Reservation_Upload_Upon_Stock_Updates' );
    Test::XTracker::Data->create_config_group( 'Automatic_Reservation_Upload_Upon_Stock_Updates', {
                                                                        channel     => $channel,
                                                                        settings    => [
                                                                                { setting => 'state', => value => $switch }
                                                                            ],
                                                                } );
    return;
}

sub _create_reservation_for_operator {
    my ( $schema, $operator_id ) = @_;
    # Grab a product.
    my($channel, $pids) = Test::XTracker::Data->grab_products( { how_many => 1 } );
    isa_ok( $channel, 'XTracker::Schema::Result::Public::Channel', 'Product channel' );
    isa_ok( $pids, 'ARRAY', 'Product PIDS' );

    # Get the first variant.
    my $variant = $pids->[0]{variant};
    isa_ok( $variant, 'XTracker::Schema::Result::Public::Variant', 'First variant' );

    # Cancel any reservations for the SKU
    $variant->reservations->update( { status_id => $RESERVATION_STATUS__CANCELLED } );

    # Create a new customer.
    my $customer_id = Test::XTracker::Data->create_test_customer( channel_id => $channel->id );
    my $customer = $schema->resultset('Public::Customer')->find( { id => $customer_id } );
    isa_ok( $customer, 'XTracker::Schema::Result::Public::Customer', 'New customer' );

    # Create a new reservation.
    my $reservation = $customer->create_related('reservations', {
        channel_id  => $channel->id,
        variant_id  => $pids->[0]->{variant_id},
        ordering_id => 1,
        operator_id => $operator_id,
        status_id   => $RESERVATION_STATUS__PENDING,
        reservation_source_id => $schema->resultset('Public::ReservationSource')->search->first->id,
        reservation_type_id => $schema->resultset('Public::ReservationType')->search->first->id,
    });
    isa_ok( $reservation, 'XTracker::Schema::Result::Public::Reservation', 'New reservation' );

    return $reservation;

}

# clean up Reservations and other items on the System so
# as not to have interference when calculating stock levels
sub _clean_up_system_for_variant {
    my ( $variant, $channel )   = @_;

    # delete all Reservations for the Variant's Product
    Test::XTracker::Data->delete_reservations( { product => $variant->product } );

    # cancel any existing shipment items to take them out of the Free stock calculation
    $variant->shipment_items->search( { shipment_item_status_id => { '!=' => $SHIPMENT_ITEM_STATUS__CANCELLED } } )
                                ->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED } );

    # update the Product Channel Transfer Status to 'None' so that the tests work
    my $prod_chann  = $variant->product->product_channel->search( { channel_id => $channel->id } )->first;
    $prod_chann->update( { transfer_status_id => $PRODUCT_CHANNEL_TRANSFER_STATUS__NONE } );

    return $prod_chann;
}


sub _test_can_update_operator {
    my ( $schema, $oktodo ) = @_;

    SKIP: {
        skip '_test_can_update_operator', 1 unless $oktodo;

        note "Running Test: test_can_update_operator";

        $schema->txn_do( sub {

            # Get the operator.
            my $operator = $schema->resultset('Public::Operator')
                ->search( { username => 'it.god' } )
                ->first;
            isa_ok( $operator, 'XTracker::Schema::Result::Public::Operator', 'New operator' );

            my $reservation = {

                # Create a reservation against our own operator.
                OWN => _create_reservation_for_operator( $schema, $operator->id ),

                # Create a reservation against another operator.
                ANY =>  _create_reservation_for_operator( $schema, $APPLICATION_OPERATOR_ID ),

            };

            my $expected_responses = {
                success             => [ 1, '' ],
                unknown_operator    => [ 0, 'the operator making the change cannot be found' ],
                do_not_own          => [ 0, q{the operator '} . $operator->name . q{' cannot change the operator of reservations they do not own} ],
                no_permission       => [ 0, q{the operator '} . $operator->name . q{' does not have permission to change the operator of this reservation} ],
                wrong_department    => [ 0, q{the operator '} . $operator->name . q{' must be in one of the following departments: Customer Care, Customer Care Manager, Personal Shopping or Fashion Advisor} ],
            };

            # Define the tests to run and the expected results.
            my @tests = (
                {
                    DEPARTMENTS => [ $DEPARTMENT__CUSTOMER_CARE, $DEPARTMENT__CUSTOMER_CARE_MANAGER, $DEPARTMENT__PERSONAL_SHOPPING, $DEPARTMENT__FASHION_ADVISOR ],
                    RESPONSE    => {
                        $AUTHORISATION_LEVEL__READ_ONLY => {
                            OWN => $expected_responses->{no_permission},
                            ANY => $expected_responses->{no_permission},
                        },
                        $AUTHORISATION_LEVEL__OPERATOR => {
                            OWN => $expected_responses->{success},
                            ANY => $expected_responses->{do_not_own},
                        },
                        $AUTHORISATION_LEVEL__MANAGER => {
                            OWN => $expected_responses->{success},
                            ANY => $expected_responses->{success},
                        },

                    },
                },
                {
                    DEPARTMENTS => [ $DEPARTMENT__IT ],
                    RESPONSE    => {
                        $AUTHORISATION_LEVEL__READ_ONLY => {
                            OWN => $expected_responses->{wrong_department},
                            ANY => $expected_responses->{wrong_department},
                        },
                        $AUTHORISATION_LEVEL__OPERATOR => {
                            OWN => $expected_responses->{wrong_department},
                            ANY => $expected_responses->{wrong_department},
                        },
                        $AUTHORISATION_LEVEL__MANAGER => {
                            OWN => $expected_responses->{wrong_department},
                            ANY => $expected_responses->{wrong_department},
                        },
                    },
                },
            );

            # Run the tests.
            foreach my $test ( @tests ) {

                foreach my $department ( @{ $test->{DEPARTMENTS} } ) {

                    # Update the department the operator is in.
                    $operator->update( { department_id => $department } );
                    my $department_name = $operator->department->department;

                    note "Department: $department_name";

                    while ( my ( $auth_level, $response ) = each %{ $test->{RESPONSE} } ) {

                        my $auth_level_name = $schema->resultset('Public::AuthorisationLevel')->find( $auth_level )->description;

                        # Update the authorisation level for the operator.
                        Test::XTracker::Data->grant_permissions( $operator->id, 'Stock Control', 'Reservation', $auth_level );

                        note "Authorisation Level: $auth_level_name";

                        foreach my $owner ( qw( OWN ANY ) ) {

                            cmp_deeply(
                                [ $reservation->{$owner}->can_update_operator( $operator ) ],
                                $response->{$owner},
                                ( $response->{$owner}->[0] == 0 ? "Can't" : "Can" ) . " update $owner reservation for $department_name / $auth_level_name"
                            );

                        }

                    }

                }

            }

            # Test we get the correct error when we use an invalid operator id.
            cmp_deeply(
                [ $reservation->{OWN}->can_update_operator( $schema->resultset('Public::Operator')->get_column('id')->max + 1 ) ],
                $expected_responses->{unknown_operator},
                'With an invalid operator ID we get the correct error' );

            $schema->txn_rollback;

        } );

    }

}

sub _test_update_operator {
    my ( $schema, $oktodo ) = @_;

    SKIP: {
        skip '_test_update_operator', 1 unless $oktodo;

        note "Running Test: test_update_operator";

        $schema->txn_do( sub {

            my $application_operator = $schema->resultset('Public::Operator')->find( $APPLICATION_OPERATOR_ID );

            # Get 2 new operators
            my ( $new_operator, $alt_operator ) = $schema->resultset('Public::Operator')
                ->search( { id => { '!=' => $application_operator->id } }, { rows => '2' } )
                ->all;
            isa_ok( $new_operator, 'XTracker::Schema::Result::Public::Operator', 'New operator' );

            # Update the operator to be in a valid department.
            $application_operator->update( { department_id => $DEPARTMENT__CUSTOMER_CARE } );

            # Update the authorisation level for the operator.
            Test::XTracker::Data->grant_permissions( $application_operator->id, 'Stock Control', 'Reservation', $AUTHORISATION_LEVEL__OPERATOR );

            # Get a new reservation.
            my $reservation = _create_reservation_for_operator( $schema, $application_operator->id );

            # Update the operator.
            cmp_deeply( [ $reservation->update_operator( $application_operator->id, $new_operator->id) ],
                [ 1, '' ], 'Got a success' );

            # Has the operator been updated.
            cmp_ok( $reservation->operator_id, '==', $new_operator->id, 'Updated reservation operator' );

            # Check the log has been populated.
            my $log_entry = $reservation->reservation_operator_logs->find( { reservation_id => $reservation->id } );
            isa_ok( $log_entry, 'XTracker::Schema::Result::Public::ReservationOperatorLog' );
            cmp_ok( $log_entry->operator_id, '==', $application_operator->id, 'Log operator ID is correct' );
            cmp_ok( $log_entry->from_operator_id, '==', $application_operator->id, 'Log FROM operator ID is correct' );
            cmp_ok( $log_entry->to_operator_id, '==', $new_operator->id, 'Log TO operator ID is correct' );
            cmp_ok( $log_entry->reservation_status_id, '==', $reservation->status_id, 'Reservation status ID is correct' );

            cmp_deeply( [ $reservation->update_operator( $application_operator->id, $new_operator->id) ],
                [ 0, 'the reservation is already assigned to the requested operator' ], 'Got the correct error' );
            cmp_ok( $reservation->discard_changes->reservation_operator_logs->count(), '==', 1, "Still only 1 Operator Log when New Operator same as Existing" );
            cmp_ok( $reservation->operator_id, '==', $new_operator->id, 'and reservation operator id is still as it was' );

            $reservation->update( { status_id => $RESERVATION_STATUS__CANCELLED } );
            cmp_deeply( [ $reservation->update_operator( $application_operator->id, $application_operator->id ) ],
                [ 0, 'the reservation is cancelled' ], 'correct error' );
            cmp_ok( $reservation->discard_changes->reservation_operator_logs->count(), '==', 1, "Still only 1 Operator Log when Reservation is now Cancelled" );
            cmp_ok( $reservation->operator_id, '==', $new_operator->id, 'and reservation operator id is still as it was' );

            $reservation->update( { status_id => $RESERVATION_STATUS__PENDING } );
            cmp_deeply( [ $reservation->update_operator( $application_operator->id, $alt_operator->id ) ],
                [ 0, q{the operator '} . $application_operator->name . q{' cannot change the operator of reservations they do not own} ], 'yup' );
            cmp_ok( $reservation->discard_changes->reservation_operator_logs->count(), '==', 1, "Still only 1 Operator Log when Reservation is NOT Owned by the Operator doing the change and their authorisation is 'Operator'" );
            cmp_ok( $reservation->operator_id, '==', $new_operator->id, 'and reservation operator id is still as it was' );

            # Update the authorisation level for manager.
            Test::XTracker::Data->grant_permissions( $application_operator->id, 'Stock Control', 'Reservation', $AUTHORISATION_LEVEL__MANAGER );

            $reservation->update( { status_id => $RESERVATION_STATUS__PENDING } );
            cmp_deeply( [ $reservation->update_operator( $application_operator->id, $alt_operator->id ) ],
                [ 1, '' ], 'success' );
            cmp_ok( $reservation->discard_changes->reservation_operator_logs->count(), '==', 2, "Now 2 Operator Logs when Operator Id has been changed for the Second time and the Operator doing the change has 'Manager' level authorisation" );
            cmp_ok( $reservation->operator_id, '==', $alt_operator->id, 'and reservation operator id has changed' );
            $log_entry  = $reservation->reservation_operator_logs->search( {}, { order_by => 'id DESC' } )->first;
            cmp_ok( $log_entry->operator_id, '==', $application_operator->id, "Log: Who DID is correct" );
            cmp_ok( $log_entry->from_operator_id, '==', $new_operator->id, "Log: Who FROM is correct" );
            cmp_ok( $log_entry->to_operator_id, '==', $alt_operator->id, "Log: Who TO is correct" );

            $schema->txn_rollback;
        } );

    }

}
