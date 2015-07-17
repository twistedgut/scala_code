package XTracker::Stock::Actions::CancelPreOrder;

use strict;
use warnings;

use Try::Tiny;

use XTracker::Handler;

use XTracker::WebContent::StockManagement;
use XTracker::Error;

use URI::Escape;


sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $schema = $handler->schema;

    my $pre_order_id    = $handler->{param_of}{pre_order_id};

    my $redirect = "/StockControl/Reservation/PreOrder/SendCancelEmail?pre_order_id=${pre_order_id}";

    my $pre_order;
    my $stock_manager;
    my $can_rollback_web    = 0;

    my $err;
    try {
        $pre_order      = $schema->resultset('Public::PreOrder')->find( $pre_order_id );
        $stock_manager  = XTracker::WebContent::StockManagement->new_stock_manager( {
                                                                    schema      => $schema,
                                                                    channel_id  => $pre_order
                                                                                        ->customer
                                                                                            ->channel_id,
                                                                } );
        $err = 0;
    }
    catch {
        xt_warn("An error occured whilst trying to get the Pre-Order to cancel:<br />$_");
        $err = 1;
    };
    return $handler->redirect_to( $redirect ) if $err;

    try {
        CANCEL: {
            my $cancel_args     = {
                        stock_manager   => $stock_manager,
                        operator_id     => $handler->operator_id,
                    };

            my $msg_suffix  = "has";

            # decide whether to Cancel Whole Pre-Order
            # or Just Selected Pre-Order Items
            if ( $handler->{param_of}{cancel_items} ) {
                # get the cancel items params out of the form
                foreach my $param ( keys %{ $handler->{param_of} } ) {
                    if ( $param =~ m/^item_to_cancel_(\d+)$/ ) {
                        my $item_id = $1;
                        push @{ $cancel_args->{items_to_cancel} }, $item_id;
                    }
                }
                if ( !$cancel_args->{items_to_cancel} ) {
                    xt_info("Was given nothing to do!");
                    last CANCEL;
                }
                $msg_suffix = "Item" . ( @{ $cancel_args->{items_to_cancel} } > 1 ? "s have" : " has" );
                # need this to send to the Email page
                $redirect   .= '&cancel_items=' . uri_escape( join( ",", sort { $a <=> $b } @{ $cancel_args->{items_to_cancel} } ) );
            }
            elsif ( $handler->{param_of}{cancel_pre_order} ) {
                $cancel_args->{cancel_pre_order}    = 1;
                # decide if any Items have already been cancelled
                # so the Email page can be passed the correct data
                if ( $pre_order->pre_order_items->cancelled->count ) {
                    my @items_to_cancel = map { $_->id } $pre_order->pre_order_items->available_to_cancel->order_by_id->all;
                    $redirect   .= '&cancel_items=' . uri_escape( join( ",", sort { $a <=> $b } @items_to_cancel ) );
                }
                $redirect   .= '&cancel_all=1';     # need this to send to the Email page
            }
            else {
                xt_warn("Wasn't Asked to Do Anything!");
                last CANCEL;
            }

            my $refund;
            $schema->txn_do( sub {
                $refund = $pre_order->cancel( $cancel_args );
                $stock_manager->commit();
            } );
            $can_rollback_web   = 0;    # flag that it's too late to rollback any Web Updates

            my $info_msg;
            my $success_msg = "Pre-Order ${msg_suffix} been Cancelled";

            if ( $refund ) {
                $redirect   .= '&refund_id=' . $refund->id;
                # if there has been a refund
                # then give the money back
                if ( $refund->refund_to_customer( { operator_id => $handler->operator_id } ) ) {
                    $success_msg    .= " - The Customer has also been Refunded";
                }
                else {
                    $info_msg   = "A Refund was generated but couldn't be processed to give the money back to the Customer:<br/>";
                    $info_msg   .= " * " . $refund->most_recent_failed_log->failure_message . "<br/>";
                    $info_msg   .= "This Refund should now appear in the Active Invoices page for the Finance Department.";
                }
            }
            else {
                $info_msg   = "NO Refund was generated whilst Cancelling";
            }
            xt_success( $success_msg );
            xt_info( $info_msg )            if ( $info_msg );

            eval {
                # don't care if this fails
                $pre_order->notify_web_app( $handler->msg_factory );
            };
        };
    }
    catch {
        xt_warn("An error occured whilst trying to cancel the Pre-Order:<br />$_");
        $stock_manager->rollback()      if ( $can_rollback_web );
        $redirect   = "/StockControl/Reservation/PreOrder/Summary?pre_order_id=${pre_order_id}";
    };
    $stock_manager->disconnect();

    return $handler->redirect_to( $redirect );
}

1;
