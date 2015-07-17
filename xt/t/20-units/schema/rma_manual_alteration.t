#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::MockObject;

BEGIN {
    use_ok( "XT::Domain::Returns" );
    can_ok( "XT::Domain::Returns", "manual_alteration" );
    use_ok( "XTracker::Order::Functions::Return::ManualReturnAlteration" );
    can_ok( "XTracker::Order::Functions::Return::ManualReturnAlteration", "_process_items" );
};

use XTracker::Constants           qw( :application );
use XTracker::Constants::FromDB   qw(
                                        :channel
                                        :currency
                                        :customer_issue_type
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                        :renumeration_status
                                        :renumeration_class
                                        :renumeration_type
                                        :return_type :return_status
                                        :return_item_status
                                    );

use XTracker::Config::Local             qw( config_var config_section_slurp dc_address );
use XTracker::Database::Invoice         qw( generate_invoice_number );
use Test::XTracker::MessageQueue;

my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

my $msg_factory = Test::XTracker::MessageQueue->new({
    schema => $schema
} );
my $retdomain   = XT::Domain::Returns->new( { msg_factory => $msg_factory, schema => $schema } );

#----- Run Tests -----

_test_cancelling_converting_one_at_a_time( $schema, $retdomain, 1 );
_test_cancelling_converting_on_mass( $schema, $retdomain, 1 );
_test_process_items_in_ManualReturnAlteration_handler( $schema, $retdomain, 1 );

#---------------------

done_testing();


# Just test Cancelling & Converting Items one at a time
sub _test_cancelling_converting_one_at_a_time {
    my $schema      = shift;
    my $retdomain   = shift;
    my $oktodo      = shift;

    SKIP: {
        skip "Test Cancelling & Converting Items One at a Time",1       if ( !$oktodo );

        note "TEST Cancelling & Converting Items One at a Time";

        $schema->txn_do( sub {
            my ( $order, $return )  = _create_an_order( undef, $retdomain );
            my $stock_manager       = $order->channel->stock_manager;
            my @ret_items           = $return->return_items->search( {}, { order_by => 'id ASC' } )->all;
            my $shipment            = $order->get_standard_class_shipment;
            my $exch_ship           = $return->exchange_shipment;
            my %items;

            my $tmp;
            my $ret_item;
            my $ship_item;
            my $exch_item;

            foreach my $item ( @ret_items ) {
                if ( $item->is_exchange ) {
                    push @{ $items{exchange}{ret_items} }, $item;
                    push @{ $items{exchange}{ship_items} }, $item->shipment_item;
                    push @{ $items{exchange}{exch_items} }, $item->exchange_shipment_item;
                }
                else {
                    push @{ $items{return}{ret_items} }, $item;
                    push @{ $items{return}{ship_items} }, $item->shipment_item;
                    push @{ $items{return}{exch_items} }, $item->exchange_shipment_item;
                }
            }

            # There were the following Returns Generated
            #       3 Returns
            #       4 Exchanges

            note "Cancel 1 Return Item";
            $ret_item   = $items{return}{ret_items}[0];
            $ship_item  = $items{return}{ship_items}[0];
            $retdomain->manual_alteration( {
                                    return_id   => $return->id,
                                    operator_id => $APPLICATION_OPERATOR_ID,
                                    num_convert_items => 0,
                                    num_cancel_items => 1,
                                    return_items=> {
                                        $ret_item->id => {
                                            remove  => 1,
                                            type => $ret_item->type->type,
                                            reason_id => $ret_item->customer_issue_type_id,
                                            shipment_item_id => $ret_item->shipment_item_id,
                                        },
                                    },
                                    stock_manager => $stock_manager,
                            } );
            _discard_changes( $ret_item, $ship_item, $return, $exch_ship );
            cmp_ok( $ret_item->return_item_status_id, '==', $RETURN_ITEM_STATUS__CANCELLED, "Return Item is 'Cancelled'" );
            cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED, "Shipment Item is 'Dispatched'" );
            cmp_ok( $return->return_status_id, '==', $RETURN_STATUS__AWAITING_RETURN, "Return Status is still 'Processing'" );

            note "Cancel 1 Exchange Item";
            $ret_item   = $items{exchange}{ret_items}[0];
            $ship_item  = $items{exchange}{ship_items}[0];
            $exch_item  = $items{exchange}{exch_items}[0];
            $retdomain->manual_alteration( {
                                    return_id   => $return->id,
                                    operator_id => $APPLICATION_OPERATOR_ID,
                                    num_convert_items => 0,
                                    num_cancel_items => 1,
                                    return_items=> {
                                        $ret_item->id => {
                                            remove  => 1,
                                            type => $ret_item->type->type,
                                            reason_id => $ret_item->customer_issue_type_id,
                                            shipment_item_id => $ret_item->shipment_item_id,
                                        },
                                    },
                                    stock_manager => $stock_manager,
                            } );
            _discard_changes( $ret_item, $ship_item, $exch_item, $return, $exch_ship );
            cmp_ok( $ret_item->return_item_status_id, '==', $RETURN_ITEM_STATUS__CANCELLED, "Exchange Return Item is 'Cancelled'" );
            cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED, "Shipment Item is 'Dispatched'" );
            cmp_ok( $exch_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__CANCELLED, "Exchange Shipment Item is 'Cancelled'" );
            cmp_ok( $return->return_status_id, '==', $RETURN_STATUS__AWAITING_RETURN, "Return Status is still 'Processing'" );
            cmp_ok( $exch_ship->shipment_status_id, '==', $SHIPMENT_STATUS__RETURN_HOLD, "Exchange Shipment Status is still 'Return Hold'" );

            note "Convert 1 Exchange Item to a Return (Refund)";
            $ret_item   = $items{exchange}{ret_items}[1];
            $ship_item  = $items{exchange}{ship_items}[1];
            $exch_item  = $items{exchange}{exch_items}[1];
            $retdomain->manual_alteration( {
                                    return_id   => $return->id,
                                    operator_id => $APPLICATION_OPERATOR_ID,
                                    num_convert_items => 1,
                                    num_cancel_items => 0,
                                    return_items=> {
                                        $ret_item->id => {
                                            remove  => 1,
                                            change => 1,
                                            type => $ret_item->type->type,
                                            reason_id => $ret_item->customer_issue_type_id,
                                            shipment_item_id => $ret_item->shipment_item_id,
                                        },
                                    },
                                    stock_manager => $stock_manager,
                            } );
            _discard_changes( $ret_item, $ship_item, $exch_item, $return, $exch_ship );
            cmp_ok( $ret_item->return_item_status_id, '==', $RETURN_ITEM_STATUS__CANCELLED, "Exchange Return Item is 'Cancelled'" );
            # get the new 'Return' Item to replace the Exchange one
            $tmp    = $return->return_items->search( {}, { order_by => 'me.id DESC', limit => 1 } )->first;
            cmp_ok( $tmp->return_type_id, '==', $RETURN_TYPE__RETURN, "New Return Item's Type is now 'Return'" );
            cmp_ok( $tmp->return_item_status_id, '==', $RETURN_ITEM_STATUS__AWAITING_RETURN, "New Return Item's Status is now 'Awaiting Return'" );
            cmp_ok( $tmp->shipment_item_id, '==', $ret_item->shipment_item_id, "New Return Shipment Item Id is same as Exchange One" );
            cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__RETURN_PENDING, "Shipment Item is still 'Return Pending'" );
            cmp_ok( $exch_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__CANCELLED, "Exchange Shipment Item is 'Cancelled'" );
            cmp_ok( $return->return_status_id, '==', $RETURN_STATUS__AWAITING_RETURN, "Return Status is still 'Processing'" );
            cmp_ok( $exch_ship->shipment_status_id, '==', $SHIPMENT_STATUS__RETURN_HOLD, "Exchange Shipment Status is still 'Return Hold'" );
            # replace old return item with new one for future tests
            $items{exchange}{ret_items}[1]  = $tmp;

            note "Convert Another Exchange Item to a Return (Refund) and Exchange Shipment should be set to Processing";
            # change data to advance items along the process
            note "Updating Statuses for some Return Items to be 'Passed QC' and the Return to be 'Processing'";
            $return->update_status( $RETURN_STATUS__PROCESSING, $APPLICATION_OPERATOR_ID );
            $items{return}{ret_items}[1]->update_status( $RETURN_ITEM_STATUS__PASSED_QC, $APPLICATION_OPERATOR_ID );
            $items{return}{ship_items}[1]->update_status( $SHIPMENT_ITEM_STATUS__RETURNED, $APPLICATION_OPERATOR_ID );
            $items{exchange}{ret_items}[1]->update_status( $RETURN_ITEM_STATUS__PASSED_QC, $APPLICATION_OPERATOR_ID );
            $items{exchange}{ship_items}[1]->update_status( $SHIPMENT_ITEM_STATUS__RETURNED, $APPLICATION_OPERATOR_ID );
            $items{exchange}{ret_items}[2]->update_status( $RETURN_ITEM_STATUS__PASSED_QC, $APPLICATION_OPERATOR_ID );
            $items{exchange}{ship_items}[2]->update_status( $SHIPMENT_ITEM_STATUS__RETURNED, $APPLICATION_OPERATOR_ID );
            $items{exchange}{ret_items}[3]->update_status( $RETURN_ITEM_STATUS__PASSED_QC, $APPLICATION_OPERATOR_ID );
            $items{exchange}{ship_items}[3]->update_status( $SHIPMENT_ITEM_STATUS__RETURNED, $APPLICATION_OPERATOR_ID );

            $ret_item   = $items{exchange}{ret_items}[2];
            $ship_item  = $items{exchange}{ship_items}[2];
            $exch_item  = $items{exchange}{exch_items}[2];
            $retdomain->manual_alteration( {
                                    return_id   => $return->id,
                                    operator_id => $APPLICATION_OPERATOR_ID,
                                    num_convert_items => 1,
                                    num_cancel_items => 0,
                                    return_items=> {
                                        $ret_item->id => {
                                            remove  => 1,
                                            change => 1,
                                            current_status_id => $ret_item->return_item_status_id,
                                            current_return_awb => 'TEST_AWB',       # test the AWB gets populated on the new Return Item
                                            type => $ret_item->type->type,
                                            reason_id => $ret_item->customer_issue_type_id,
                                            shipment_item_id => $ret_item->shipment_item_id,
                                        },
                                    },
                                    stock_manager => $stock_manager,
                            } );
            _discard_changes( $ret_item, $ship_item, $exch_item, $return, $exch_ship );
            cmp_ok( $ret_item->return_item_status_id, '==', $RETURN_ITEM_STATUS__CANCELLED, "Exchange Return Item is 'Cancelled'" );
            # get the new 'Return' Item to replace the Exchange one
            $tmp    = $return->return_items->search( {}, { order_by => 'me.id DESC', limit => 1 } )->first;
            cmp_ok( $tmp->return_type_id, '==', $RETURN_TYPE__RETURN, "New Return Item's Type is now 'Return'" );
            cmp_ok( $tmp->return_item_status_id, '==', $RETURN_ITEM_STATUS__PASSED_QC, "New Return Item's Status is still 'Passed QC'" );
            is( $tmp->return_airway_bill, "TEST_AWB", "New Return Item's AWB is 'TEST_AWB'" );
            cmp_ok( $tmp->shipment_item_id, '==', $ret_item->shipment_item_id, "New Return Shipment Item Id is same as Exchange One" );
            cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__RETURNED, "Shipment Item Status is still 'Returned'" );
            cmp_ok( $exch_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__CANCELLED, "Exchange Shipment Item is 'Cancelled'" );
            cmp_ok( $return->return_status_id, '==', $RETURN_STATUS__PROCESSING, "Return Status is still 'Processing'" );
            cmp_ok( $exch_ship->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING, "Exchange Shipment Status is now 'Processing'" );
            # replace old return item with new one for future tests
            $items{exchange}{ret_items}[2]  = $tmp;

            note "Cancel a Return which should change the Return Status to be 'Complete'";
            $ret_item   = $items{return}{ret_items}[2];
            $ship_item  = $items{return}{ship_items}[2];
            $retdomain->manual_alteration( {
                                    return_id   => $return->id,
                                    operator_id => $APPLICATION_OPERATOR_ID,
                                    num_convert_items => 0,
                                    num_cancel_items => 1,
                                    return_items=> {
                                        $ret_item->id => {
                                            remove  => 1,
                                            type => $ret_item->type->type,
                                            reason_id => $ret_item->customer_issue_type_id,
                                            shipment_item_id => $ret_item->shipment_item_id,
                                        },
                                    },
                                    stock_manager => $stock_manager,
                            } );
            _discard_changes( $ret_item, $ship_item, $return );
            cmp_ok( $ret_item->return_item_status_id, '==', $RETURN_ITEM_STATUS__CANCELLED, "Return Item is 'Cancelled'" );
            cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED, "Shipment Item is 'Dispatched'" );
            cmp_ok( $return->return_status_id, '==', $RETURN_STATUS__COMPLETE, "Return Status is now 'Complete'" );

            $schema->txn_rollback();
        } ); # schema->txn_do

    }; # SKIP

    return;
}

# Test Cancelling & Converting Items on mass
sub _test_cancelling_converting_on_mass {
    my $schema      = shift;
    my $retdomain   = shift;
    my $oktodo      = shift;

    SKIP: {
        skip "Test Cancelling & Converting Items on Mass",1       if ( !$oktodo );

        note "TEST Cancelling & Converting Items on Mass in One Go";

        $schema->txn_do( sub {
            my ( $order, $return )  = _create_an_order( undef, $retdomain );
            my $stock_manager       = $order->channel->stock_manager;
            my @ret_items           = $return->return_items->search( {}, { order_by => 'id ASC' } )->all;
            my $shipment            = $order->get_standard_class_shipment;
            my $exch_ship           = $return->exchange_shipment;
            my %items;

            my $tmp;
            my $ret_item;
            my $ship_item;
            my $exch_item;

            foreach my $item ( @ret_items ) {
                if ( $item->is_exchange ) {
                    push @{ $items{exchange}{ret_items} }, $item;
                    push @{ $items{exchange}{ship_items} }, $item->shipment_item;
                    push @{ $items{exchange}{exch_items} }, $item->exchange_shipment_item;
                }
                else {
                    push @{ $items{return}{ret_items} }, $item;
                    push @{ $items{return}{ship_items} }, $item->shipment_item;
                    push @{ $items{return}{exch_items} }, $item->exchange_shipment_item;
                }
            }

            # There were the following Returns Generated
            #       3 Returns
            #       4 Exchanges

            note "Changing the data before doing test";

            $return->update_status( $RETURN_STATUS__PROCESSING, $APPLICATION_OPERATOR_ID );

            # Returns first
            foreach my $idx ( 0..1 ) {
                $items{return}{ret_items}[$idx]->update_status( $RETURN_ITEM_STATUS__PASSED_QC, $APPLICATION_OPERATOR_ID );
                $items{return}{ship_items}[$idx]->update_status( $SHIPMENT_ITEM_STATUS__RETURNED, $APPLICATION_OPERATOR_ID );
            }

            # Exchanges Second
            foreach my $idx ( 0..2 ) {
                $items{exchange}{ret_items}[$idx]->update_status( $RETURN_ITEM_STATUS__PASSED_QC, $APPLICATION_OPERATOR_ID );
                $items{exchange}{ship_items}[$idx]->update_status( $SHIPMENT_ITEM_STATUS__RETURNED, $APPLICATION_OPERATOR_ID );
            }

            # build up the return items to cancel/convert
            my %return_items;
            # first to convert
            foreach my $item ( $items{exchange}{ret_items}[1], $items{exchange}{ret_items}[2] ) {
                $return_items{ $item->id }  = {
                        remove => 1,
                        change => 1,
                        current_status_id => $item->return_item_status_id,
                        current_return_awb => "TEST_AWB_".$item->id,
                        type => $item->type->type,
                        reason_id => $item->customer_issue_type_id,
                        shipment_item_id => $item->shipment_item_id,
                    };
            }
            # then to cancel
            foreach my $item ( $items{exchange}{ret_items}[3], $items{return}{ret_items}[2] ) {
                $return_items{ $item->id }  = {
                        remove => 1,
                        type => $item->type->type,
                        reason_id => $item->customer_issue_type_id,
                        shipment_item_id => $item->shipment_item_id,
                    };
            }

            # alter the Return
            $retdomain->manual_alteration( {
                                    return_id   => $return->id,
                                    operator_id => $APPLICATION_OPERATOR_ID,
                                    num_convert_items => 2,
                                    num_cancel_items => 2,
                                    return_items => \%return_items,
                                    stock_manager => $stock_manager,
                            } );
            _discard_changes( $return, $exch_ship );
            _discard_changes( @{ $items{exchange}{ret_items} }, @{ $items{exchange}{ship_items} }, @{ $items{exchange}{exch_items} } );
            _discard_changes( @{ $items{return}{ret_items} }, @{ $items{return}{ship_items} } );
            # check the cancelations
            foreach my $item ( $items{exchange}{ret_items}[3], $items{return}{ret_items}[2] ) {
                note "Checking ".$item->type->type." was Cancelled";
                cmp_ok( $item->return_item_status_id, '==', $RETURN_ITEM_STATUS__CANCELLED, "Return Item is 'Cancelled'" );
                cmp_ok( $item->shipment_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED, "Shipment Item is 'Dispatched'" );
                if ( $item->is_exchange ) {
                    cmp_ok( $item->exchange_shipment_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__CANCELLED, "Exchange Shipment Item is 'Cancelled'" );
                }
            }
            # check the convertions
            foreach my $idx ( 1..2 ) {
                my $ret_item    = $items{exchange}{ret_items}[$idx];
                my $ship_item   = $items{exchange}{ship_items}[$idx];
                my $exch_item   = $items{exchange}{exch_items}[$idx];

                note "Checking Exchange was Converted: ".$ret_item->id;

                my $tmp = $return->return_items->search( { shipment_item_id => $ret_item->shipment_item_id } )->count();
                cmp_ok( $tmp, '==', 2, "Should be now 2 return records for the Shipment Item Id" );

                # get the new Return record created
                $tmp    = $return->return_items->search( {
                                                    shipment_item_id => $ret_item->shipment_item_id,
                                                    return_item_status_id => { '!=' => $RETURN_ITEM_STATUS__CANCELLED },
                                                } )->first;

                cmp_ok( $ret_item->return_item_status_id, '==', $RETURN_ITEM_STATUS__CANCELLED, "Exchange Item is 'Cancelled'" );
                cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__RETURNED, "Shipment Item Status is still 'Returned'" );
                cmp_ok( $exch_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__CANCELLED, "Shipment Item Status is 'Cancelled'" );
                cmp_ok( $tmp->return_type_id, '==', $RETURN_TYPE__RETURN, "New Return Type is a 'Return'" );
                cmp_ok( $tmp->return_item_status_id, '==', $RETURN_ITEM_STATUS__PASSED_QC, "New Return Status is 'Passed QC'" );
                is( $tmp->return_airway_bill, "TEST_AWB_".$ret_item->id, "New Return Item's AWB is 'TEST_AWB_".$ret_item->id."'" );
            }
            # check the status of the Return & Exchange Shipment as a whole
            cmp_ok( $return->return_status_id, '==', $RETURN_STATUS__COMPLETE, "Return is now 'Complete'" );
            cmp_ok( $exch_ship->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING, "Exchange Shipment is now 'Processing'" );

            $schema->txn_rollback();
        } ); # schema->txn_do

    }; # SKIP

    return;
}

# test the function '_process_items' in XTracker::Order::Functions::Return::ManualReturnAlteration
sub _test_process_items_in_ManualReturnAlteration_handler {
    my $schema      = shift;
    my $retdomain   = shift;
    my $oktodo      = shift;

    SKIP: {
        skip "Test the '_process_items' function in the ManualReturnAlteration Handler",1       if ( !$oktodo );

        note "TEST the '_process_items' function in the ManualReturnAlteration Handler";

        $schema->txn_do( sub {
            my ( $order, $return )  = _create_an_order( undef, $retdomain );
            my @ret_items           = $return->return_items->search( {}, { order_by => 'id ASC' } )->all;
            my $shipment            = $order->get_standard_class_shipment;
            my $exch_ship           = $return->exchange_shipment;
            my %items;

            my $handler;
            my $tmp;

            foreach my $item ( @ret_items ) {
                if ( $item->is_exchange ) {
                    push @{ $items{exchange}{ret_items} }, $item;
                    push @{ $items{exchange}{ship_items} }, $item->shipment_item;
                    push @{ $items{exchange}{exch_items} }, $item->exchange_shipment_item;
                }
                else {
                    push @{ $items{return}{ret_items} }, $item;
                    push @{ $items{return}{ship_items} }, $item->shipment_item;
                    push @{ $items{return}{exch_items} }, $item->exchange_shipment_item;
                }
            }

            # test passing nothing into the function
            $handler    = _init_mock_handler( $schema, $msg_factory, {
                                            data => {
                                                return => $return,
                                            },
                                            param_of => {
                                            }
                                    } );
            my $stock_manager = $shipment->get_channel->stock_manager;
            ($tmp) = XTracker::Order::Functions::Return::ManualReturnAlteration::_process_items( $handler, $stock_manager );
            cmp_ok( $tmp, '==', 0, "Pass nothing in to convert or cancel and return ZERO" );

            # try and convert a 'Return' and it should do
            # nothing as you can only convert an 'Exchange'
            $handler    = _init_mock_handler( $schema, $msg_factory, {
                                            data => {
                                                return => $return,
                                            },
                                            param_of => {
                                                "convert-".$items{return}{ret_items}[0]->id => 1,
                                            }
                                    } );
            ($tmp) = XTracker::Order::Functions::Return::ManualReturnAlteration::_process_items( $handler, $stock_manager );
            cmp_ok( $tmp, '==', 0, "Converting a 'Return' instead of an 'Exchange' should do nothing and return ZERO" );

            # test passing something for the function to do
            $handler    = _init_mock_handler( $schema, $msg_factory, {
                                            data => {
                                                return => $return,
                                            },
                                            param_of => {
                                                "convert-".$items{exchange}{ret_items}[0]->id => 1,
                                                "cancel-".$items{return}{ret_items}[0]->id => 1,
                                            }
                                    } );
            ($tmp) = XTracker::Order::Functions::Return::ManualReturnAlteration::_process_items( $handler, $stock_manager );
            cmp_ok( $tmp, '==', 2, "Process 2 Items should return 2" );
            _discard_changes( $return );
            _discard_changes( @{ $items{exchange}{ret_items} }, @{ $items{exchange}{ship_items} }, @{ $items{exchange}{exch_items} } );
            _discard_changes( @{ $items{return}{ret_items} }, @{ $items{return}{ship_items} } );
            cmp_ok( $items{return}{ret_items}[0]->return_item_status_id, '==', $RETURN_ITEM_STATUS__CANCELLED, "Return Item is 'Cancelled'" );
            cmp_ok( $items{return}{ship_items}[0]->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED, "Shipment Item is 'Dispatched'" );
            cmp_ok( $items{exchange}{ret_items}[0]->return_item_status_id, '==', $RETURN_ITEM_STATUS__CANCELLED, "Exchange Item is 'Cancelled'" );
            cmp_ok( $items{exchange}{exch_items}[0]->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__CANCELLED, "Exchange Shipment Item is 'Cancelled'" );

            # test passing in the same again and should do nothing as there
            # is nothing to convert or cancel anymore it's already been done
            # test passing something for the function to do
            $handler    = _init_mock_handler( $schema, $msg_factory, {
                                            data => {
                                                return => $return,
                                            },
                                            param_of => {
                                                "convert-".$items{exchange}{ret_items}[0]->id => 1,
                                                "cancel-".$items{return}{ret_items}[0]->id => 1,
                                            }
                                    } );
            ($tmp) = XTracker::Order::Functions::Return::ManualReturnAlteration::_process_items( $handler, $stock_manager );
            cmp_ok( $tmp, '==', 0, "Do things twice and it should do nothing and return ZERO" );

            $schema->txn_rollback;
        } ); # schema->txn_do

    }; # SKIP

    return;
}

################################################################################

# set-up a mock Handler
sub _init_mock_handler {
    my $schema  = shift;
    my $domain  = shift;
    my $args    = shift;

    # set-up a Mock Handler;
    my $mock_handler    = Test::MockObject->new( $args );
    $mock_handler->set_isa('XTracker::Handler');
    $mock_handler->set_always( operator_id => $APPLICATION_OPERATOR_ID );
    $mock_handler->set_always( schema => $schema );
    $mock_handler->set_always( msg_factory => $retdomain->msg_factory );
    $mock_handler->set_always( domain => $retdomain );

    return $mock_handler;
}

# discard changes for all passed in records
sub _discard_changes {
    my @recs    = @_;
    foreach my $rec ( @recs ) {
        $rec->discard_changes;
    }
}

# reset data for another test
sub _reset_data {
}

# create an order
sub _create_an_order {
    my $args        = shift;
    my $retdomain   = shift;

    my $num_pids    = 7;

    note "Creating Order";

    my($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => $num_pids,
    });

    my $ship_account    = Test::XTracker::Data->find_shipping_account( { carrier => config_var('DistributionCentre','default_carrier'), channel_id => $channel->id } );
    my $prem_postcode   = Test::XTracker::Data->find_prem_postcode( $channel->id );
    my $postcode        = ( defined $prem_postcode ? $prem_postcode->postcode :
                            ( $channel->is_on_dc( 'DC2' ) ? '11371' : 'NW10 4GR' ) );

    my $dc_address = dc_address($channel);
    my $address         = Test::XTracker::Data->order_address( {
                                                address         => 'create',
                                                address_line_1  => $dc_address->{addr1},
                                                address_line_2  => $dc_address->{addr2},
                                                address_line_3  => $dc_address->{addr3},
                                                towncity        => $dc_address->{city},
                                                county          => '',
                                                country         => $args->{country} || $dc_address->{country},
                                                postcode        => $postcode,
                                            } );

    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

    my $base = {
        customer_id => $customer->id,
        channel_id  => $channel->id,
        shipment_type => $SHIPMENT_TYPE__DOMESTIC,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id => $ship_account->id,
        invoice_address_id => $address->id,
    };


    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => $base,
        attrs => [ map { price => $_ * 100, tax => 0, duty => 0 }, ( 1..$num_pids ) ],
    });

    # clean up data created by the 'create order' test function
    $order->tenders->delete;
    my $shipment    = $order->shipments->first;
    $shipment->renumerations->delete;
    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'id ASC' } )->all;

    note "Order Id/Nr: ".$order->id." / ".$order->order_nr;
    note "Shipment Id: ".$shipment->id;

    # create an initial DEBIT invoice
    my $invoice_number = generate_invoice_number( $schema->storage->dbh );
    my $renum   = $shipment->create_related( 'renumerations', {
                                invoice_nr              => $invoice_number,
                                renumeration_type_id    => $RENUMERATION_TYPE__CARD_DEBIT,
                                renumeration_class_id   => $RENUMERATION_CLASS__ORDER,
                                renumeration_status_id  => $RENUMERATION_STATUS__COMPLETED,
                                shipping    => 10,
                                currency_id => ( Test::XTracker::Data->whatami eq 'DC2' ? $CURRENCY__USD : $CURRENCY__GBP ),
                                sent_to_psp => 1,
                                gift_credit => 0,
                                misc_refund => 0,
                                store_credit=> 0,
                                gift_voucher=> 0,
                        } );
    foreach my $item ( @ship_items ) {
        $renum->create_related( 'renumeration_items', {
                                shipment_item_id    => $item->id,
                                unit_price          => $item->unit_price,
                                tax                 => $item->tax,
                                duty                => $item->duty,
                            } );
        note "Shipment Item Id: ".$item->id.", Price: ".$item->unit_price.", Tax: ".$item->tax.", Duty: ".$item->duty;
        $item->update_status( $SHIPMENT_ITEM_STATUS__DISPATCHED, $APPLICATION_OPERATOR_ID );
    }
    $shipment->update_status( $SHIPMENT_STATUS__DISPATCHED, $APPLICATION_OPERATOR_ID );

    $order->create_related( 'tenders', {
                                value   => $renum->grand_total,
                                type_id => $RENUMERATION_TYPE__CARD_DEBIT,
                                rank    => 0,
                            } );

    # create a return
    my $return  = $retdomain->create( {
                        operator_id => $APPLICATION_OPERATOR_ID,
                        shipment_id => $shipment->id,
                        pickup  => 0,
                        refund_type_id  => $RENUMERATION_TYPE__CARD_REFUND,
                        return_items => {
                                $ship_items[0]->id => {
                                    type => 'Exchange',
                                    reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                    exchange_variant => $ship_items[0]->variant_id,
                                },
                                $ship_items[1]->id => {
                                    type => 'Return',
                                    reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                },
                                $ship_items[2]->id => {
                                    type => 'Exchange',
                                    reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                    exchange_variant => $ship_items[2]->variant_id,
                                },
                                $ship_items[3]->id => {
                                    type => 'Return',
                                    reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                },
                                $ship_items[4]->id => {
                                    type => 'Exchange',
                                    reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                    exchange_variant => $ship_items[4]->variant_id,
                                },
                                $ship_items[5]->id => {
                                    type => 'Exchange',
                                    reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                    exchange_variant => $ship_items[5]->variant_id,
                                },
                                $ship_items[6]->id => {
                                    type => 'Return',
                                    reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                },
                            },
                    } );
    note "Created Return: ".$return->id." / ".$return->rma_number;

    $order->discard_changes;
    $return->discard_changes;

    # complete the Return Renumeration
    my @renums  = $return->renumerations->all;
    foreach my $renum ( @renums ) {
        $renum->update_status( $RENUMERATION_STATUS__COMPLETED, $APPLICATION_OPERATOR_ID );
    }

    return ( $order, $return );
}
