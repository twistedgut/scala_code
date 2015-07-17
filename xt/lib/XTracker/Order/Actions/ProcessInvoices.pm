package XTracker::Order::Actions::ProcessInvoices;

use strict;
use warnings;

use Data::Dump qw(pp);

use XTracker::Handler;
use XTracker::Database::Currency;
use XTracker::Database::Customer;
use XTracker::Database::Invoice;
use XTracker::Database::Order;
use XTracker::Database;

use XTracker::Order::Printing::RefundForm;
use XTracker::Error;

use XT::Domain::Payment;

use XTracker::Constants::FromDB qw(
    :renumeration_class
    :renumeration_status
    :renumeration_type
    :pre_order_refund_status
);

sub handler {
    my $r = shift;

    my $handler = XTracker::Handler->new($r);
    my $hash_ref = $handler->get_postdata();
    my %postdata = %{ $hash_ref };

    my $redirect_url = '/Finance/ActiveInvoices';

    # if no form data submitted redirect back
    return $handler->redirect_to( $redirect_url )
        unless scalar keys(%postdata);

    # set up XT and web db handles
    my $schema = $handler->schema;
    my $dbh    = $schema->storage->dbh;

    # Get a new database connection for refund_to_customer (required for
    # updating the sent_to_psp flag).
    my $dbh_override = XTracker::Database->xtracker_schema_no_singleton->storage->dbh;

    my $error_msg   = '';

    my $operator_id    = $handler->operator_id;

    # process each invoice submitted

    REFUND:
    foreach my $item ( keys %postdata ) {

        # skip if form field doesn't match expected format (action-invoice_id)
        next REFUND if $item !~ m/-/;

        # split action and invoice_id out of field name
        my ($action, $invoice_id) = split /-/, $item;

        if ( $postdata{$item} == 1 ) {

            my ($renumeration, $order );

            if( $action eq 'reset_sent_to_psp_preorder' || $action eq 'refund_and_complete_preorder') {
                # Get pre_order_refund (invoice) and pre-order objects.
                $renumeration    = $schema->resultset('Public::PreOrderRefund')->find($invoice_id);
                $order           = $renumeration->pre_order;
            } else  {
               # Get renumeration (invoice) and order.
               $renumeration    = $schema->resultset('Public::Renumeration')->find($invoice_id);
               $order           = $renumeration->shipment->link_orders__shipment->order;
            }

            eval {

                my $guard = $schema->txn_scope_guard;

                # ACTION: Invoice completed.
                if ( $action eq "complete" || $action eq "refund_and_complete" ) {

                    unless ( $renumeration->sent_to_psp ) {

                        # Skip if invoice completed or cancelled.
                        next REFUND
                            if ( $renumeration->renumeration_status_id == $RENUMERATION_STATUS__COMPLETED
                              || $renumeration->renumeration_status_id == $RENUMERATION_STATUS__CANCELLED );

                        $renumeration->refund_to_customer( {
                            refund_and_complete => $action eq 'refund_and_complete' ? 1 : 0,
                            message_factory     => $handler->msg_factory,
                            operator_id         => $operator_id,
                            dbh_override        => $dbh_override,
                        } );

                        $renumeration->discard_changes;

                        # Sleep for one second - Spoke to Ben, he explained this was originally put in, as the service would think it
                        # was being 'attacked' and would timeout when repeated requests where made. Only required in loops.
                        sleep 1;


                    } else {

                        die 'Attempting to complete invoice ' . $renumeration->invoice_nr . ' that has already been sent to the PSP.';

                    }

                }
                # ACTION: refund and complete for preorder record
                elsif ( $action eq "refund_and_complete_preorder" ) {
                    unless ( $renumeration->sent_to_psp ) {

                        # Skip if invoice completed or cancelled.
                        next REFUND
                            if ( $renumeration->pre_order_refund_status_id == $PRE_ORDER_REFUND_STATUS__COMPLETE
                              || $renumeration->pre_order_refund_status_id == $PRE_ORDER_REFUND_STATUS__CANCELLED);

                        $renumeration->refund_to_customer( {
                            operator_id         => $operator_id,
                            dbh_override        => $dbh_override,
                        } );

                        $renumeration->discard_changes;

                        # Sleep for one second - Spoke to Ben, he explained this was originally put in, as the service would think it
                        # was being 'attacked' and would timeout when repeated requests where made. Only required in loops.
                        sleep 1;


                    } else {

                        die 'Attempting to complete invoice ' . $renumeration->invoice_nr . ' that has already been sent to the PSP.';

                    }


                }

                # ACTION: Print invoice form
                elsif ( $action eq "print" ) {

                    if ( $renumeration->renumeration_class_id == $RENUMERATION_CLASS__RETURN ) {

                        # Check to see if the RMA has been cancelled.
                        $renumeration->check_rma_not_cancelled;

                    }

                    # CANDO- 65: skip printing for debit
                    my $print_result = 1;
                    if( $renumeration->renumeration_type_id != $RENUMERATION_TYPE__CARD_DEBIT ) {

                        # print refund form
                        $print_result = generate_refund_form( $dbh, $invoice_id, "Finance", 1 );
                    } #END of CANDO-65

                    # Update status of invoice to 'printed'.
                    if ( $print_result == 1 ) {

                        update_invoice_status( $dbh, $invoice_id, $RENUMERATION_STATUS__PRINTED );
                        log_invoice_status( $dbh, $invoice_id, $RENUMERATION_STATUS__PRINTED, $operator_id );

                    } else {

                        die "Printer error!";

                    }

                }

                # ACTION: Reset sent_to_psp.
                elsif ( $action eq "reset_sent_to_psp" || $action eq "reset_sent_to_psp_preorder" ) {

                    if ( $renumeration->sent_to_psp ) {

                        $renumeration->update( { sent_to_psp => 0 } );

                    }

                }

                # ACTION: Not sure, we should've done everything by now.
                else {

                    die "Unknown or inappropriate action: $action";

                }

                $guard->commit();

            };

            if ( my $error = $@ ) {

                # Add eval error to error message if we don't have one already.
                if ( !$error_msg ) {
                    if( $action =~ /preorder/) {
                        $error_msg .= "- Error processing order " . $order->pre_order_number . ": $error" ;
                    } else {
                        $error_msg .= "- Error processing order " . $order->order_nr . ": $error" ;
                    }
                }
                last REFUND;

            } else {

                if ($action =~ /complete/ && $action !~ /preorder/) {

                    $handler->msg_factory->transform_and_send( 'XT::DC::Messaging::Producer::Orders::Update', { order_id => $order->id } );

                }

            }

        }

    }

    # Tag error message onto redirect url if we got one.
    xt_warn( $error_msg ) if $error_msg;

    # We're done, redirect back.
    return $handler->redirect_to( $redirect_url );

}

1;
