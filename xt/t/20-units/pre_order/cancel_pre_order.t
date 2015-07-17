#!/usr/bin/perl
use NAP::policy "tt",     'test';

=head2 Cancelling a Pre Order/Pre Order Items

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Mock::PSP;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :department
                                        :pre_order_status
                                        :pre_order_item_status
                                        :pre_order_refund_status
                                        :reservation_status
                                    );
use XTracker::Database;


# get a schema, sanity check
my $schema  = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");


#----------------------------------------------------------
_test_refunding_pre_order_payment( $schema, 1 );
_test_cancelling_pre_order_and_items( $schema, 1 );
_test_pre_order_refund( $schema, 1 );
#----------------------------------------------------------

done_testing();

# test re-funding the Pre Order Payment
sub _test_refunding_pre_order_payment {
    my ( $schema, $oktodo ) = @_;

    SKIP: {
        skip '_test_refunding_pre_order_payment', 1     if ( !$oktodo );

        note "TESTING refunding_pre_order_payment";

        $schema->txn_do( sub {
            my $pre_order       = Test::XTracker::Data::PreOrder->create_complete_pre_order;
            my $preord_payment  = $pre_order->pre_order_payment;

            note "testing: 'psp_refund_the_amount' method";

            cmp_ok( $preord_payment->psp_refund_the_amount, '==', 0,
                                    "returns FALSE when passed with NO Amount to refund" );

            #Test::XTracker::Mock::PSP->refund_action('PASS');
            throws_ok{
                $preord_payment->psp_refund_the_amount(-12);
            } qr/PreOrder Id: \d+/i, "is trying to create refund with invalid amount";

            #Test::XTracker::Mock::PSP->refund_action('PASS');
            cmp_ok( $preord_payment->psp_refund_the_amount(0), '==', 0,
                                    "returns FALSE when passed with Zero Amount to refund" );


            Test::XTracker::Mock::PSP->refund_action('PASS');
            cmp_ok( $preord_payment->psp_refund_the_amount( 100.34 ), '==', 1,
                                    "returns TRUE when Successful Refund" );

            Test::XTracker::Mock::PSP->refund_action('FAIL-2');
            throws_ok {
                    $preord_payment->psp_refund_the_amount( 100.34 );
                } qr/Pre Order Id: \d+/i, "die's when there is a Failure to Refund to the PSP with an expected message";


            # rollback any changes
            $schema->txn_rollback();
        } );
    };

    return;
}

# test Cancelling a Pre-Order as a whole
# or cancelling Pre-Order Items
sub _test_cancelling_pre_order_and_items {
    my ( $schema, $oktodo ) = @_;

    SKIP: {
        skip '_test_cancelling_pre_order_and_items', 1      if ( !$oktodo );

        note "TESTING cancelling_pre_order_and_items";

        $schema->txn_do( sub {
            # get all Reservations & Pre-Order Items created for the Pre-Order & clear any logs
            my $pre_order       = Test::XTracker::Data::PreOrder->create_complete_pre_order;
            my $channel         = $pre_order->customer->channel;
            my @pre_order_items = $pre_order->pre_order_items->search( undef, { order_by => 'id' } )->all;
            $pre_order->search_related('pre_order_status_logs')->delete;
            my @reservations;
            foreach my $item ( @pre_order_items ) {
                push @reservations, $item->reservation;
                $item->search_related('pre_order_item_status_logs')->delete;
            }

            # get any operator that isn't the Application Operator
            my $operator    = _get_operator();

            # make sure any calls to PSP are ok
            Test::XTracker::Mock::PSP->refund_action('PASS');

            # get a Stock Management object to pass to methods
            my $stock_manager   = _stock_manager( $schema, $channel );

            # take a copy of the Status Id for the Pre-Order
            my $pre_order_status_id = $pre_order->pre_order_status->id;

            # check for missing parameters
            _check_method_params( $pre_order, $stock_manager );

            note "TEST: 'cancel' method for a Pre-Order Item";
            my $item        = $pre_order_items[-1];
            my $reservation = $reservations[-1];

            cmp_ok( $pre_order->pre_order_items->available_to_cancel->count(), '==', @pre_order_items,
                            "Pre-Order Item Result-Set Method 'available_to_cancel' returns all Items when nothing Cancelled: " . @pre_order_items );

            # when Pre-Order Item doesn't have a Reservation then
            # there is no need to pass a Stock Management object
            $item->update( { reservation_id => undef } );
            lives_ok { $item->cancel; } "When item has no Reservation then Ok to pass NO Stock Management Object to 'cancel' method";
            cmp_ok( $item->discard_changes->is_cancelled, '==', 1, "Pre-Order Item has been Cancelled" );
            my $log = $item->pre_order_item_status_logs->first;
            isa_ok( $log, 'XTracker::Schema::Result::Public::PreOrderItemStatusLog', "Found an Item Status Log record" );
            cmp_ok( $log->pre_order_item_status_id, '==', $PRE_ORDER_ITEM_STATUS__CANCELLED, "Log has 'Cancelled' Status" );
            cmp_ok( $log->operator_id, '==', $APPLICATION_OPERATOR_ID, "and is for the Application Operator" );
            # cancel the same thing twice nothing should happen
            lives_ok { $item->cancel(); } "Cancelling Already Cancelled Item is Fine";
            cmp_ok( $item->discard_changes->is_cancelled, '==', 1, "Item is STILL Cancelled" );
            cmp_ok( $item->pre_order_item_status_logs->count(), '==', 1, "STILL only ONE Log created" );


            note "TEST: 'cancel' an Item with a Reservation";
            $item       = $pre_order_items[0];
            $reservation= $reservations[0];
            $item->cancel( $stock_manager, $operator->id );
            cmp_ok( $item->discard_changes->is_cancelled, '==', 1, "Pre-Order Item has been Cancelled" );
            cmp_ok( $reservation->discard_changes->status_id, '==', $RESERVATION_STATUS__CANCELLED,
                                                "Reservation has been Cancelled" );
            $log    = $item->pre_order_item_status_logs->first;
            isa_ok( $log, 'XTracker::Schema::Result::Public::PreOrderItemStatusLog', "Found an Item Status Log record" );
            cmp_ok( $log->pre_order_item_status_id, '==', $PRE_ORDER_ITEM_STATUS__CANCELLED, "Log has 'Cancelled' Status" );
            cmp_ok( $log->operator_id, '==', $operator->id, "and is for the Operator: " . $operator->name );

            cmp_ok( $pre_order->discard_changes->pre_order_items->available_to_cancel->count(), '==', ( @pre_order_items - 2 ),
                            "Pre-Order Item Result-Set Method 'available_to_cancel' returns only NON-Cancelled Items: " . ( @pre_order_items - 2 ) );


            note "TEST: 'cancel' method for Pre-Order";
            my $refund;
            my @refund_ids;
            my $refund_count= $pre_order->pre_order_refunds->count();

            cmp_ok( $pre_order->all_items_are_cancelled, '==', 0,
                            "Pre-Order 'all_items_are_cancelled' method returns FALSE when there are still NON Cancelled Items" );

            note "TEST: cancel 1 item only";
            $item       = $pre_order_items[1];
            lives_ok {
                    $refund = $pre_order->cancel( { stock_manager => $stock_manager, items_to_cancel => [ $item->id ] } );
                } "Cancelling only One Item";
            cmp_ok( $pre_order->discard_changes->pre_order_status_id, '==', $pre_order_status_id,
                            "Pre-Order Status hasn't changed" );
            cmp_ok( $item->discard_changes->is_cancelled, '==', 1, "Pre-Order Item has been Cancelled" );
            cmp_ok( $item->pre_order_item_status_logs->first->operator_id, '==', $APPLICATION_OPERATOR_ID,
                            "Log for the Item Cancelled is for the Application Operator" );
            $refund_count   = _check_refund_ok( $refund, $refund_count, [ $item ] );
            push @refund_ids, $refund->id;

            note "TEST: cancel all the rest of the items, should cancel the Pre-Order as well";
            my @items   = @pre_order_items[2..($#pre_order_items-1)];
            $refund = $pre_order->cancel( {
                                stock_manager   => $stock_manager,
                                operator_id     => $operator->id,
                                items_to_cancel => [ map { $_->id } @items ],
                            } );
            cmp_ok( $pre_order->discard_changes->is_cancelled, '==', 1,
                            "Pre-Order Record is now Cancelled" );
            foreach my $item ( @items ) {
                cmp_ok( $item->discard_changes->is_cancelled, '==', 1,
                            "Pre-Order Item is now Cancelled, Id: " . $item->id );
                cmp_ok( $item->pre_order_item_status_logs->first->operator_id, '==', $operator->id,
                            "Log for the Item Cancelled is for the Operator: " . $operator->name );
            }
            $log    = $pre_order->pre_order_status_logs->first;
            isa_ok( $log, 'XTracker::Schema::Result::Public::PreOrderStatusLog', "Found a Pre-Order Status Log record" );
            cmp_ok( $log->pre_order_status_id, '==', $PRE_ORDER_STATUS__CANCELLED, "Log has 'Cancelled' Status" );
            cmp_ok( $log->operator_id, '==', $operator->id, "and is for the Operator: " . $operator->name );

            cmp_ok( $pre_order->discard_changes->pre_order_items->available_to_cancel->count(), '==', 0,
                            "Pre-Order Item Result-Set Method 'available_to_cancel' now returns ZERO when all Items have been Cancelled" );
            cmp_ok( $pre_order->all_items_are_cancelled, '==', 1,
                            "Pre-Order 'all_items_are_cancelled' method returns TRUE when all Items have been Cancelled" );
            $refund_count   = _check_refund_ok( $refund, $refund_count, [ @items ], $operator->id );
            push @refund_ids, $refund->id;

            note "check 'list_for_summary_page' method for Pre-Order's Refunds";
            my @expected_list_keys  = qw(
                                        refund_id
                                        refund_obj
                                        created_date
                                        status_date
                                        status
                                        total_value
                                        operator_name
                                        department
                                    );
            my $list    = $pre_order->pre_order_refunds->list_for_summary_page;
            isa_ok( $list, 'ARRAY', "method returned expected result" );
            is_deeply( [ map { $_->{refund_id} } @{ $list } ], \@refund_ids, "and the List has all of the Refunds in the expected sequence" );
            isa_ok( $list->[0], 'HASH', "first element is as expected" );
            is_deeply( [ map { $_ } sort keys %{ $list->[0] } ], [ sort @expected_list_keys ], "and has the expected keys in it" );


            note "TEST: cancel the Pre-Order as a Whole";
            $pre_order      = Test::XTracker::Data::PreOrder->create_complete_pre_order( { with_no_status_logs => 1  } );   # need a new Pre-Order

            # just check 'list_for_summary_page' method when there are no refunds
            $list   = $pre_order->pre_order_refunds->list_for_summary_page;
            cmp_ok( @{ $list }, '==', 0, "'list_for_summary_page' method when there are NO Refunds returns empty Array Ref" );

            $refund_count   = $pre_order->pre_order_refunds->count();
            @items          = $pre_order->pre_order_items->all;
            $items[0]->cancel( $stock_manager );                # cancel 1 item first, to test the
                                                                # remaining items get Cancelled next
            $refund = $pre_order->cancel( {
                                stock_manager   => $stock_manager,
                                operator_id     => $operator->id,
                                cancel_pre_order=> 1,
                            } );
            cmp_ok( $pre_order->discard_changes->is_cancelled, '==', 1,
                            "Passing 'cancel_pre_order' with 1 Item already Cancelled, Pre-Order is now Cancelled" );
            $log    = $pre_order->pre_order_status_logs->first;
            cmp_ok( $log->pre_order_status_id, '==', $PRE_ORDER_STATUS__CANCELLED, "Log has 'Cancelled' Status" );
            cmp_ok( $log->operator_id, '==', $operator->id, "and is for the Operator: " . $operator->name );
            foreach my $idx ( 1..$#items ) {
                $item   = $items[ $idx ];
                cmp_ok( $item->discard_changes->is_cancelled, '==', 1,
                            "Pre-Order Item is now Cancelled, Id: " . $item->id );
                cmp_ok( $item->pre_order_item_status_logs->first->operator_id, '==', $operator->id,
                            "Log for the Item Cancelled is for the Operator: " . $operator->name );
            }
            $refund_count   = _check_refund_ok( $refund, $refund_count, [ map { $items[ $_ ] } 1..$#items ], $operator->id );

            # get another Pre-Order to test Cancelling all of it in one go
            $pre_order      = Test::XTracker::Data::PreOrder->create_complete_pre_order( { with_no_status_logs => 1 } );
            $refund_count   = $pre_order->pre_order_refunds->count();
            @items          = $pre_order->pre_order_items->all;
            $refund = $pre_order->cancel( {
                                stock_manager   => $stock_manager,
                                cancel_pre_order=> 1,
                            } );
            cmp_ok( $pre_order->discard_changes->is_cancelled, '==', 1,
                            "Passing 'cancel_pre_order' with ZERO Items already Cancelled, Pre-Order is now Cancelled" );
            $log    = $pre_order->pre_order_status_logs->first;
            cmp_ok( $log->pre_order_status_id, '==', $PRE_ORDER_STATUS__CANCELLED, "Log has 'Cancelled' Status" );
            cmp_ok( $log->operator_id, '==', $APPLICATION_OPERATOR_ID, "and is for the Application Operator" );
            foreach my $item ( @items ) {
                cmp_ok( $item->discard_changes->is_cancelled, '==', 1,
                            "Pre-Order Item is now Cancelled, Id: " . $item->id );
                cmp_ok( $item->pre_order_item_status_logs->first->operator_id, '==', $APPLICATION_OPERATOR_ID,
                            "Log for the Item Cancelled is for the Application Operator" );
            }
            $refund_count   = _check_refund_ok( $refund, $refund_count, [ @items ] );

            # cancel it again shouldn't be an issue
            $refund = $pre_order->cancel( {
                                stock_manager   => $stock_manager,
                                cancel_pre_order=> 1,
                                operator_id     => $operator->id,
                            } );
            cmp_ok( $pre_order->discard_changes->is_cancelled, '==', 1,
                            "Cancelling a Pre-Order for a Second time and the Pre-Order is STILL Cancelled" );
            cmp_ok( $pre_order->pre_order_status_logs->count, '==', 1, "STILL only 1 Status Log" );
            $log    = $pre_order->pre_order_status_logs->first;
            cmp_ok( $log->operator_id, '==', $APPLICATION_OPERATOR_ID, "and is STILL for the Application Operator" );
            ok( !defined $refund, "Cancelling an Already Cancelled Pre-Order should generate NO Refund" );
            cmp_ok( $pre_order->pre_order_refunds->count(), '==', $refund_count, "and the Total of Refunds for the Pre-Order hasn't increased" );

            note "TEST: cancel Pre-Order when some of the Items are still 'New', refund should only be generated for the 'Complete' Items";
            $pre_order      = Test::XTracker::Data::PreOrder->create_complete_pre_order;      # need a new Pre-Order
            $refund_count   = $pre_order->pre_order_refunds->count();
            @items          = $pre_order->pre_order_items->all;

            # set one item to be 'Selected'
            $items[0]->update( { pre_order_item_status_id => $PRE_ORDER_ITEM_STATUS__SELECTED } );
            $refund = $pre_order->cancel( {
                                        stock_manager   => $stock_manager,
                                        cancel_pre_order=> 1,
                                        operator_id     => $operator->id,
                                    } );
            cmp_ok( $pre_order->discard_changes->is_cancelled, '==', 1, "Pre-Order has been Cancelled" );
            foreach my $item ( @items ) {
                cmp_ok( $item->discard_changes->is_cancelled, '==', 1,
                            "Pre-Order Item is now Cancelled, Id: " . $item->id );
            }
            $refund_count   = _check_refund_ok( $refund, $refund_count, [ map { $items[ $_ ] } 1..$#items ], $operator->id );


            # rollback any changes
            $schema->txn_rollback();
        } );
    };

    return;
}

# tests using the Pre-Order Refund
# functionality
sub _test_pre_order_refund {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_pre_order_refund", 1        if ( !$oktodo );

        note "TESTING pre_order_refund";

        my $refund;
        my $refund_status_log_rs;
        my $refund_failed_log_rs;
        my $failed_log;
        my $status_log;

        # get any operator that isn't the Application Operator
        my $operator    = _get_operator();

        # start off in a transaction
        $schema->txn_do( sub {
            my $pre_order   = Test::XTracker::Data::PreOrder->create_complete_pre_order;
            my $channel     = $pre_order->customer->channel;
            my $payment     = $pre_order->pre_order_payment;

            # get a Stock Management object to pass to methods
            my $stock_manager   = _stock_manager( $schema, $channel );

            # generate a Refund for the Pre-Order
            $refund = $pre_order->cancel( { stock_manager => $stock_manager, cancel_pre_order => 1 } );
            $refund_status_log_rs   = $refund->pre_order_refund_status_logs->search( {
                                                                            pre_order_refund_status_id  => $PRE_ORDER_REFUND_STATUS__FAILED,
                                                                        }, { order_by => 'id DESC' } );
            $refund_failed_log_rs   = $refund->pre_order_refund_failed_logs->search( undef, { order_by => 'id DESC' } );

            ok( !defined $refund->most_recent_failed_log, "'most_recent_failed_log' method returns 'undef' when there are none" );

            note "TEST: Setting/Clearing PSP Flag";
            $refund->update( { sent_to_psp => 0 } );
            $refund->set_sent_to_psp_flag;
            cmp_ok( $refund->discard_changes->sent_to_psp, '==', 1, "'set_sent_to_psp_flag' method sets 'sent_to_psp' to TRUE" );
            $refund->clear_sent_to_psp_flag;
            cmp_ok( $refund->discard_changes->sent_to_psp, '==', 0, "'clear_sent_to_psp_flag' method sets 'sent_to_psp' to FALSE" );


            note "TEST: 'mark_as_failed_via_psp' method";
            # just test it needs a a Failure Message passed to it
            throws_ok {
                    $refund->mark_as_failed_via_psp();
                } qr/No Failure Message Passed/i, "When called without a Failure Message dies with expected error";
            $failed_log = $refund->mark_as_failed_via_psp("Failure Message");
            $status_log = $refund_status_log_rs->reset->first;
            cmp_ok( $refund->pre_order_refund_status_id, '==', $PRE_ORDER_REFUND_STATUS__FAILED, "Refund Status is now 'Failed'" );
            isa_ok( $failed_log, 'XTracker::Schema::Result::Public::PreOrderRefundFailedLog', "Failed Log Created" );
            is( $failed_log->failure_message, "Failure Message", "Failure Message as Expected on Log" );
            is( $failed_log->preauth_ref_used, $payment->preauth_ref, "Preauth Ref as Expected on Log" );
            cmp_ok( $failed_log->operator_id, '==', $APPLICATION_OPERATOR_ID, "Operator Id on Log is for Application User" );
            my $prev_failed_log_id  = $failed_log->id;
            $failed_log = $refund->most_recent_failed_log;
            isa_ok( $failed_log, 'XTracker::Schema::Result::Public::PreOrderRefundFailedLog', "'most_recent_failed_log' method returned a Failed Log" );
            cmp_ok( $failed_log->id, '==', $prev_failed_log_id, "and the Id of that log is for the correct one" );
            isa_ok( $status_log, 'XTracker::Schema::Result::Public::PreOrderRefundStatusLog', "Status Log Created" );
            cmp_ok( $status_log->pre_order_refund_status_id, '==', $PRE_ORDER_REFUND_STATUS__FAILED, "Status Id is 'Failed' on Log" );
            cmp_ok( $status_log->operator_id, '==', $APPLICATION_OPERATOR_ID, "Operator Id on Log is for Application User" );

            note "TEST: Subsequent call to 'mark_as_failed_via_psp' method";
            $failed_log = $refund->mark_as_failed_via_psp( "Another Failure Message", $operator->id );
            $status_log = $refund_status_log_rs->reset->first;
            isa_ok( $failed_log, 'XTracker::Schema::Result::Public::PreOrderRefundFailedLog', "Failed Log Created" );
            cmp_ok( $refund_failed_log_rs->count(), '==', 2, "2 Failed Logs Created in Total" );
            cmp_ok( $failed_log->id, '>', $prev_failed_log_id, "and it's New as the Log Id is greater than for the Previous Log" );
            is( $failed_log->failure_message, "Another Failure Message", "Different Failure Message as Expected on Log" );
            cmp_ok( $failed_log->operator_id, '==', $operator->id, "Operator Id on Log is for Operator: " . $operator->name );
            cmp_ok( $refund_status_log_rs->count(), '==', 1, "Still Only 1 'Failed' Status Log Created" );
            cmp_ok( $status_log->operator_id, '==', $APPLICATION_OPERATOR_ID, "Operator Id is Still for Application Operator" );

            note "TEST: Change Status to be 'Pending' and then call 'mark_as_failed_via_psp' again";
            $refund->discard_changes->update( { pre_order_refund_status_id => $PRE_ORDER_REFUND_STATUS__PENDING } );
            $failed_log = $refund->mark_as_failed_via_psp( "Subsequent Failure Message", $operator->id );
            $status_log = $refund_status_log_rs->reset->first;
            cmp_ok( $refund->pre_order_refund_status_id, '==', $PRE_ORDER_REFUND_STATUS__FAILED, "Refund Status is 'Failed'" );
            cmp_ok( $refund_failed_log_rs->count(), '==', 3, "Now 3 Failed Logs Created in Total" );
            is( $failed_log->failure_message, "Subsequent Failure Message", "New Failure Message as Expected on Log" );
            $prev_failed_log_id = $failed_log->id;
            $failed_log = $refund->most_recent_failed_log;
            isa_ok( $failed_log, 'XTracker::Schema::Result::Public::PreOrderRefundFailedLog', "'most_recent_failed_log' method returned a Failed Log" );
            cmp_ok( $refund_status_log_rs->count(), '==', 2, "Now 2 'Failed' Status Logs Created" );
            cmp_ok( $status_log->operator_id, '==', $operator->id, "Operator Id on Log is for Operator: " . $operator->name );


            # clear out logs
            $refund->pre_order_refund_status_logs->delete;
            $refund->pre_order_refund_failed_logs->delete;
            cmp_ok( $refund_status_log_rs->count(), '==', 0, "Status Logs Cleared" );


            #make total_value =0
            $refund->pre_order_refund_items->update({ unit_price => 0, tax => 0 , duty => 0 });

            note "TEST: 'refund_to_customer' method";


            throws_ok {
                    $refund->refund_to_customer();
                } qr/Invalid amount given for creation of refund/i,
                    "method dies when 'pre_order_refund' is called with Zero Amount";

            $refund->pre_order_refund_items->update({ unit_price => 100,tax =>10 , duty => 10 });

            $refund->discard_changes->update( {
                                                pre_order_refund_status_id  => $PRE_ORDER_REFUND_STATUS__PENDING,
                                                sent_to_psp                 => 0,   # set 'sent_to_psp' flag to FALSE
                                            } );
            throws_ok {
                    $refund->refund_to_customer();
                } qr/'sent_to_psp' flag STILL FALSE/i,
                    "method dies when 'pre_order_refund' record has not been committed to the DB";

            # ending 'txn_do' here should commit the record
        } );

        # Now no longer in a transaction

        # just get the latest version
        $refund->discard_changes;

        # get a seperate DB connection
        my $separate_schema = XTracker::Database::xtracker_schema_no_singleton();
        my $dbh = $separate_schema->storage->dbh;
        $separate_schema->txn_do(sub{
            throws_ok {
                    $refund->refund_to_customer( { dbh_override => $dbh } );
                } qr/'dbh_override' argument not Auto-Commit Enabled/i,
                        "method dies when passed a NON Auto-Commit enabled DBH as it can't set 'sent_to_psp' flag";
            $separate_schema->txn_rollback;
        });
        $refund->discard_changes;

        my %statuses            = map { $_->id => $_ } $schema->resultset('Public::PreOrderRefundStatus')->all;
        my @notallow_statuses   = map { delete $statuses{ $_ } } (
                                                                    $PRE_ORDER_REFUND_STATUS__COMPLETE,
                                                                    $PRE_ORDER_REFUND_STATUS__CANCELLED,
                                                                 );
        # XXX Danger Will Robinson! Unsorted Hash Behaviour Under perl 5.18!
        my @allow_statuses      = values %statuses;
        foreach my $status ( @notallow_statuses ) {
            $refund->update( { pre_order_refund_status_id => $status->id } );
            cmp_ok( $refund->refund_to_customer, '==', 0, "For Status: " . $status->status . ", method returns FALSE" );
        }

        Test::XTracker::Mock::PSP->refund_action('PASS');   # just set the PSP to PASS the Refund
        foreach my $status ( @allow_statuses ) {
            $refund->update( { pre_order_refund_status_id => $status->id, sent_to_psp => 0 } );
            cmp_ok( $refund->refund_to_customer, '==', 1, "For Status: " . $status->status . ", method returns TRUE" );
        }

        # reset the record to PENDING so that the next tests will work; FAILED
        # used to be a potential value here but breaks tests when combined
        # with true random ordering from %values
        $refund->update( { pre_order_refund_status_id => $PRE_ORDER_REFUND_STATUS__PENDING, sent_to_psp => 0 } );

        # clear out logs
        $refund->discard_changes->pre_order_refund_status_logs->delete;
        $refund->pre_order_refund_failed_logs->delete;

        note "test when PSP Fails";
        cmp_ok( $refund_status_log_rs->count(), '==', 0, "Status Logs Empty" );
        Test::XTracker::Mock::PSP->refund_action('FAIL-2');
        cmp_ok( $refund->refund_to_customer( { operator_id => $operator->id } ), '==', 0, "when PSP Fails then method returns FALSE" );
        cmp_ok( $refund_status_log_rs->count(), '==', 1, "Now 1 'Failed' Status Logs Created" );
        cmp_ok( $refund->discard_changes->is_failed, '==', 1, "Refund Status is now 'Failed'" );
        cmp_ok( $refund->sent_to_psp, '==', 1, "'sent_to_psp' field is TRUE" );
        $status_log = $refund_status_log_rs->reset->first;
        $failed_log = $refund_failed_log_rs->reset->first;
        isa_ok( $status_log, 'XTracker::Schema::Result::Public::PreOrderRefundStatusLog', "Failed Status Log Created" );
        cmp_ok( $status_log->operator_id, '==', $operator->id, "Operator Id on Log is for Operator: " . $operator->name );
        isa_ok( $failed_log, 'XTracker::Schema::Result::Public::PreOrderRefundFailedLog', "Failed Log Created" );
        cmp_ok( $failed_log->operator_id, '==', $operator->id, "Operator Id on Log is for Operator: " . $operator->name );
        like( $failed_log->failure_message, qr/transaction has been rejected/i, "Failed Message is as Expected: '" . $failed_log->failure_message . "'" );

        note "test when PSP Passes";
        Test::XTracker::Mock::PSP->refund_action('PASS');
        $refund->update( { sent_to_psp => 0 } );
        cmp_ok( $refund->refund_to_customer(), '==', 1, "when PSP Passes then method returns TRUE" );
        cmp_ok( $refund->discard_changes->is_complete, '==', 1, "Refund Status is now 'Complete'" );
        cmp_ok( $refund->sent_to_psp, '==', 1, "'sent_to_psp' field is TRUE" );
        $status_log = $refund->pre_order_refund_status_logs->search( undef, { order_by => 'id DESC' } )->first;
        isa_ok( $status_log, 'XTracker::Schema::Result::Public::PreOrderRefundStatusLog', "Failed Status Log Created" );
        cmp_ok( $status_log->pre_order_refund_status_id, '==', $PRE_ORDER_REFUND_STATUS__COMPLETE, "Log Status is 'Complete'" );
        cmp_ok( $status_log->operator_id, '==', $APPLICATION_OPERATOR_ID,
                                "Passing NO Operator Id means Operator Id on Log is for the Application Operator" );
        cmp_ok( $refund_failed_log_rs->reset->count(), '==', 1, "Still only 1 Failed Log for the Refund" );
        my $data_sent_to_psp    = Test::XTracker::Mock::PSP->get_refund_data_in;
        my $refund_total= sprintf( "%0.2f", $refund->total_value );
        $refund_total   =~ s/\.//g;
        is( $data_sent_to_psp->{coinAmount}, $refund_total, "Total Amount to be Refunded that the PSP received is correct: " . $refund_total );


        note "test when passed a 'dbh_override' argument & PSP Passes";
        # NOTE: I've commented the line below but I don't understand what the
        # 'reset everything to use it' bit means, so I'm not sure what needs to
        # be 'undone' and what's ok. If you have the time and the inclination
        # please clean up the below code...

        # turn on Auto-Commit for DBH and reset everything to use it
        #$dbh->{AutoCommit}  = 1;
        $refund->discard_changes->pre_order_refund_status_logs->delete;
        $refund->pre_order_refund_failed_logs->delete;
        $refund->discard_changes->update( { pre_order_refund_status_id => $PRE_ORDER_REFUND_STATUS__PENDING, sent_to_psp => 0 } );

        cmp_ok( $refund->refund_to_customer( { dbh_override => $dbh, operator_id => $operator->id } ), '==', 1,
                                "when using 'dbh_override' to set the 'sent_to_psp' flag, method returns TRUE" );
        cmp_ok( $refund->discard_changes->is_complete, '==', 1, "Refund Status is now 'Complete'" );
        cmp_ok( $refund->sent_to_psp, '==', 1, "'sent_to_psp' field is TRUE" );
        $status_log = $refund->pre_order_refund_status_logs->search( undef, { order_by => 'id DESC' } )->first;
        isa_ok( $status_log, 'XTracker::Schema::Result::Public::PreOrderRefundStatusLog', "Failed Status Log Created" );
        cmp_ok( $status_log->pre_order_refund_status_id, '==', $PRE_ORDER_REFUND_STATUS__COMPLETE, "Log Status is 'Complete'" );
        cmp_ok( $status_log->operator_id, '==', $operator->id,
                                "Operator Id on Log is for the Operator: " . $operator->name );
        cmp_ok( $refund_failed_log_rs->reset->count(), '==', 0, "ZERO Failed Logs for the Refund" );
    };

    return;
}

#---------------------------------------------------------------------------------------------

# check the Refund generated for the Cancellation
# process is for the Items and the Value expected
sub _check_refund_ok {
    my ( $refund, $existing_count, $items, $operator_id )   = @_;

    $operator_id    //= $APPLICATION_OPERATOR_ID;

    $existing_count++;

    isa_ok( $refund, 'XTracker::Schema::Result::Public::PreOrderRefund', "Found a Refund record" );
    my $new_count   = $refund->pre_order->pre_order_refunds->count();
    cmp_ok( $new_count, '==',  $existing_count, "Found the Correct number of Refunds for the Pre-Order" );

    my @sorted_items    = sort { $a->id <=> $b->id } @{ $items };
    my @refund_items    = $refund->pre_order_refund_items
                                    ->search( undef, { order_by => 'pre_order_item_id' } )
                                        ->all;
    cmp_ok( @refund_items, '==', @sorted_items, "Number of Refund Items as Expected: " . @sorted_items );

    my $total_value = 0.00;
    foreach my $idx ( 0..$#refund_items ) {
        my $p_item  = $sorted_items[ $idx ];
        my $r_item  = $refund_items[ $idx ];

        my $label   = "Refund Item - " . ( $idx + 1 ) . ":";

        cmp_ok( $r_item->pre_order_item_id, '==', $p_item->id, "$label Pre-Order Item Id is for expected Pre Order Item" );
        is( _d2( $r_item->unit_price ), _d2( $p_item->unit_price ), "$label Unit Price same as for the Pre Order Item" );
        is( _d2( $r_item->tax ), _d2( $p_item->tax ), "$label Tax same as for the Pre Order Item" );
        is( _d2( $r_item->duty ), _d2( $p_item->duty ), "$label Duty same as for the Pre Order Item" );

        $total_value    += ( $p_item->unit_price + $p_item->tax + $p_item->duty );
    }
    is( _d2( $refund->total_value ), _d2( $total_value ), "Refund's Total Value as expected: " . _d2( $total_value ) );

    my $log = $refund->pre_order_refund_status_logs->first;
    isa_ok( $log, 'XTracker::Schema::Result::Public::PreOrderRefundStatusLog', "Found a Log for the Refund" );
    cmp_ok( $log->pre_order_refund_status_id, '==', $PRE_ORDER_REFUND_STATUS__PENDING, "Log Status is 'Pending' ");
    cmp_ok( $log->operator_id, '==', $operator_id, "Log is for the Expected Operator Id: $operator_id" );

    return $existing_count;
}

# check to make sure methods fail when
# not passed the correct parameters
sub _check_method_params {
    my ( $pre_order, $stock_manager )   = @_;

    # get a Pre-Order Item
    my $item    = $pre_order->pre_order_items->first;

    note "Check methods for correct Parameters";

    note "pre_order_item->cancel";
    throws_ok { $item->cancel; } qr/No 'Stock Management' object passed/i,
                    "Cancelling an item with a Reservation without a Stock Management Object passed dies with expected message";

    note "pre_order->cancel";
    throws_ok { $pre_order->cancel; } qr/Missing Args HASH Ref/i,
                    "Passing No Argument HASH Ref to 'cancel' method dies with expected message";
    throws_ok { $pre_order->cancel( { } ); } qr/No 'Stock Management' object passed/,
                    "Passing No Stock Management Object dies with expected message";
    throws_ok {
                $pre_order->cancel( {
                            stock_manager => { },
                        } );
              } qr/No 'Stock Management' object passed/,
                "Passing the 'stock_manager' argumnet but with a NON Stock Management Object dies with expected message";
    throws_ok {
                $pre_order->cancel( {
                            stock_manager => $stock_manager,
                        } );
              } qr/Neither 'items_to_cancel' Array Ref or 'cancel_pre_order' passed/i,
                "Passing neither 'cancel_pre_order' or 'items_to_cancel' dies with expected message";
    throws_ok {
                $pre_order->cancel( {
                            stock_manager => $stock_manager,
                            items_to_cancel => { },
                        } );
              } qr/Neither 'items_to_cancel' Array Ref or 'cancel_pre_order' passed/i,
                "Passing 'items_to_cancel' but not as an Array Ref dies with expected message";
    throws_ok {
                $pre_order->cancel( {
                            stock_manager => $stock_manager,
                            cancel_pre_order => 0,
                        } );
              } qr/Neither 'items_to_cancel' Array Ref or 'cancel_pre_order' passed/i,
                "Passing 'cancel_pre_order' as FALSE dies with expected message";

    note "FINISHED - Check methods for correct Parameters";

    return;
}

# change value passed to have 2 decimal places
sub _d2 {
    my $value   = shift;
    return sprintf( "%0.2f", $value );
}

# get a Stock Management Object
sub _stock_manager {
    my ( $schema, $channel )    = @_;
    return XTracker::WebContent::StockManagement->new_stock_manager( { schema => $schema, channel_id => $channel->id } );
}

# get an Operator that isn't the Application Operator
sub _get_operator {
    my $op  = $schema->resultset('Public::Operator')
                    ->search( { id => { '!=' => $APPLICATION_OPERATOR_ID } } )
                        ->first;
    $op->update( { department_id => $DEPARTMENT__PERSONAL_SHOPPING } );

    return $op->discard_changes;
}

