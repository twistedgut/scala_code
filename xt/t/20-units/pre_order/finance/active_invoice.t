#!/usr/bin/perl
use NAP::policy "tt",     'test';

=head2 CANDO -949

This Test would check the following

1) "rs_for_active_invoice_page" method returns correct result set.

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Mock::PSP;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :department
                                        :pre_order_status
                                        :pre_order_refund_status
                                    );
use XTracker::Database              qw( get_database_handle );


# get a schema, sanity check
my $schema  = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");


#----------------------------------------------------------
_test_rs_for_active_invoice_page_method($schema, 1 );
#----------------------------------------------------------

done_testing();

sub _test_rs_for_active_invoice_page_method {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_rs_for_active_invoice_page_method", 1        if ( !$oktodo );

        note "TESTING _test_rs_for_active_invoice_page_method";

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

            my $stock_manager   = _stock_manager( $channel );

            # generate a Refund for the Pre-Order
            $refund = $pre_order->cancel( { stock_manager => $stock_manager, cancel_pre_order => 1 } );


            note "TEST: 'rs_for_active_invoice_page' method - Failed Refunds";

            my $refund_rs = $schema->resultset('Public::PreOrderRefund')->rs_for_active_invoice_page();
            my $result_rs = $refund_rs->search ( { 'me.id' => $refund->id });

            # the result set return refund_items, so count would be greater than one.
            cmp_ok( $result_rs->count, '>', 0, "Resultset returns Failed Refunds" );


            note "TEST: 'rs_for_active_invoice_page' method - Pending Refunds";
            #update the status of refund to pending
            $refund->update_status( $PRE_ORDER_REFUND_STATUS__PENDING, $operator->id );
            $refund->discard_changes;
            $result_rs = $refund_rs->search ( { 'me.id' => $refund->id });
            cmp_ok( $result_rs->count, '>', 0, "Resultset returns Pending Refunds" );

            note "TEST: 'rs_for_active_invoice_page' method - Cancelled";
            #update the status of refund to cancelled
            $refund->update_status( $PRE_ORDER_REFUND_STATUS__CANCELLED, $operator->id );
            $refund->discard_changes;
            $result_rs = $refund_rs->search ( { 'me.id' => $refund->id });
            cmp_ok( $result_rs->count, '==', 0, "Resultset does Not returns Cancelled Refunds" );

            note "TEST: 'rs_for_active_invoice_page' method - Complete";
            #update the status of refund to complete
            $refund->update_status( $PRE_ORDER_REFUND_STATUS__COMPLETE, $operator->id );
            $refund->discard_changes;
            $result_rs = $refund_rs->search ( { 'me.id' => $refund->id });
            cmp_ok( $result_rs->count, '==', 0, "Resultset does Not returns Complete Refunds" );

            # rollback any changes
            $schema->txn_rollback();
        } );

    };

    return;
}



#---------------------------------------------------------------------------------------------


# get a Stock Management Object
sub _stock_manager {
    my ($channel )    = @_;
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

