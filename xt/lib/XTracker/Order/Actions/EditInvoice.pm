package XTracker::Order::Actions::EditInvoice;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Invoice     qw(
                                        :DEFAULT
                                        adjust_existing_renum_tenders
                                        update_card_tender_value
                                        payment_can_allow_goodwill_refund_for_card
                                    );
use XTracker::Database::Return;
use XTracker::Database::Shipment;

use XTracker::Utilities             qw( parse_url );
use XTracker::Constants             qw( :refund_error_messages );
use XTracker::Constants::FromDB     qw(
                                        :renumeration_class
                                        :renumeration_status
                                        :renumeration_type
                                        :shipment_status
                                    );
use XTracker::Error;

sub handler {
    ## no critic(ProhibitDeepNests)
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    my $schema      = $handler->schema;

    # set up vars and get query string data
    my $invalid_msg     = '';
    my $renum_id        = 0;
    my $total_renum     = 0;
    my $order_id        = $handler->{param_of}{order_id};
    my $shipment_id     = $handler->{param_of}{shipment_id};
    my $invoice_id      = $handler->{param_of}{invoice_id};
    my $redirect_url    = $short_url.'/Invoice?invoice_id='.$invoice_id.'&order_id='.$order_id.'&shipment_id='.$shipment_id;

    eval {
        my $order = $schema->resultset('Public::Orders')->find( $order_id );

        # check the Payment Method can handle a pure Goodwill Refund to Credit Card
        my $can_proceed = payment_can_allow_goodwill_refund_for_card(
            $order,
            $handler->{param_of}{misc_refund},
            $handler->{param_of}{type_id},
        );
        unless( $can_proceed ) {
            my $payment_method = $order->payments->first->payment_method->payment_method;
            die sprintf( $GOODWILL_REFUND_AGAINST_CARD_ERR_MSG, $payment_method ) . "\n";
        }

        my $guard = $schema->txn_scope_guard;

        # get the current invoice data
        my $refund_info         = get_invoice_info( $handler->{dbh}, $invoice_id );
        my $refund_item_info    = get_invoice_item_info( $handler->{dbh}, $invoice_id );

        # set up shipment id and current status vars
        my $shipment_id         = $refund_info->{shipment_id};
        my $current_status_id   = $refund_info->{renumeration_status_id};

        # get pre check data to stop people refunding too much
        my $shipment            = get_shipment_info($handler->{dbh}, $shipment_id);
        my $shipment_item       = get_shipment_item_info($handler->{dbh}, $shipment_id);

        # calculate original shipment value
        my $orig_shipment_value = 0;

        $orig_shipment_value    -= $shipment->{store_credit};

        foreach my $ship_item_id ( keys %{ $shipment_item } ) {
            $orig_shipment_value += $shipment_item->{ $ship_item_id }{unit_price} + $shipment_item->{ $ship_item_id }{tax} + $shipment_item->{ $ship_item_id }{duty};
        }

        # take off any existing refunds from shipment values before checking against current refund
        my $refunds = get_shipment_invoices( $handler->{dbh}, $shipment_id );

        foreach my $ref_id ( keys %{ $refunds } ) {

            if ( $ref_id != $invoice_id && $refunds->{$ref_id}{renumeration_type_id} < $RENUMERATION_TYPE__CARD_DEBIT && $refunds->{$ref_id}{renumeration_status_id} < $RENUMERATION_STATUS__CANCELLED  ){

                # take off shipping
                $shipment->{shipping_charge} -= $refunds->{$ref_id}{shipping};

                $refunds->{$ref_id}{renum_item} = get_invoice_item_info( $handler->{dbh}, $ref_id );

                foreach my $ref_item_id ( keys %{ $refunds->{$ref_id}{renum_item} } ) {
                    $shipment_item->{ $refunds->{$ref_id}{renum_item}{$ref_item_id}{shipment_item_id} }{unit_price} -= $refunds->{$ref_id}{renum_item}{$ref_item_id}{unit_price};
                    $shipment_item->{ $refunds->{$ref_id}{renum_item}{$ref_item_id}{shipment_item_id} }{tax} -= $refunds->{$ref_id}{renum_item}{$ref_item_id}{tax};
                    $shipment_item->{ $refunds->{$ref_id}{renum_item}{$ref_item_id}{shipment_item_id} }{duty} -= $refunds->{$ref_id}{renum_item}{$ref_item_id}{duty};
                }
            }
        }


        # now do the updates

        # debit authorised by customer care
        if ( exists $handler->{param_of}{auth_debit} and $handler->{param_of}{auth_debit} == 1 ){

            # set update status to pending
            my $update_id = $RENUMERATION_STATUS__PENDING;

            # need to check if the return has already been completed - then status needs to be awaiting action

            # find return for invoice
            my $return_id = get_invoice_return( $handler->{dbh}, $invoice_id );

            if ( $return_id > 0 ) {
                # check if return is complete
                my ($complete, $exchange_complete) = check_return_complete($handler->{dbh}, $return_id);

                # return completed - set update status to awaiting action
                if ($complete == 1){
                    $update_id = $RENUMERATION_STATUS__AWAITING_ACTION;
                }
            }

            # update status and log it
            update_invoice_status( $handler->{dbh}, $invoice_id, $update_id );
            log_invoice_status( $handler->{dbh}, $invoice_id, $update_id, $handler->{data}{operator_id} );
        }
                # refund manually released
        elsif ( exists $handler->{param_of}{release} and $handler->{param_of}{release} == 1 ){

            update_invoice_status($handler->{dbh}, $invoice_id, $RENUMERATION_STATUS__AWAITING_ACTION);
            log_invoice_status( $handler->{dbh}, $invoice_id, $RENUMERATION_STATUS__AWAITING_ACTION, $handler->{data}{operator_id} );

        }
        # invoice cancelled
        elsif ( exists $handler->{param_of}{cancel} and $handler->{param_of}{cancel} == 1){

            # delete any renumeration tenders
            my $renum   = $schema->resultset('Public::Renumeration')->find( $invoice_id );
            my $renum_tenders   = $renum->renumeration_tenders;
            while ( my $tender = $renum_tenders->next ) {
                $tender->delete;
            }

            update_invoice_status($handler->{dbh}, $invoice_id, $RENUMERATION_STATUS__CANCELLED);
            log_invoice_status( $handler->{dbh}, $invoice_id, $RENUMERATION_STATUS__CANCELLED, $handler->{data}{operator_id} );

        }
        # invoice edited
        else {

            # get current invoice value for the change logging later
            my $current_value = get_invoice_value($handler->{dbh}, $invoice_id);

            # sanity check values entered when editing
            if ( $handler->{param_of}{status_id} != $RENUMERATION_STATUS__COMPLETED && $handler->{param_of}{status_id} != $RENUMERATION_STATUS__CANCELLED ) {
                if ( $handler->{param_of}{shipping} > $shipment->{shipping_charge} ){
                    die 'The amount of shipping refunded is greater than the amount charged';
                }
                # prevent 'use of unitialised value' warnings
                $handler->{param_of}{misc_refund}  ||= 0;
                $handler->{param_of}{gift_credit}  ||= 0;
                $handler->{param_of}{store_credit} ||= 0;
                if (
                    (
                        $handler->{param_of}{misc_refund} +
                        $handler->{param_of}{gift_credit} +
                        $handler->{param_of}{store_credit}
                    ) > $orig_shipment_value
                  )
                {
                    die 'The value of the refund is greater than the original shipment total';
                }
            }

            # update renumeration table
            edit_invoice(
                $handler->{dbh},
                $invoice_id,
                $handler->{param_of}{type_id},
                $handler->{param_of}{status_id},
                $handler->{param_of}{shipping},
                $handler->{param_of}{misc_refund},
                $handler->{param_of}{gift_credit},
                $handler->{param_of}{store_credit},
                $handler->{param_of}{alt_customer} || 0,
            );

            # log status change if required
            if ( $current_status_id != $handler->{param_of}{status_id} ) {

                log_invoice_status(
                    $handler->{dbh},
                    $invoice_id,
                    $handler->{param_of}{status_id},
                    $handler->{data}{operator_id}
                );

                # if status changed to 'completed' then extra steps required
                if ( $handler->{param_of}{status_id} == $RENUMERATION_STATUS__COMPLETED ) {

                    # generate invoice number and write back against invoice
                    my $invoice_number = generate_invoice_number($handler->{dbh});

                    update_invoice_number($handler->{dbh}, $invoice_id, $invoice_number);

                    # release exchange shipments if required
                    my $return_id = get_invoice_return( $handler->{dbh}, $invoice_id );

                    # found a return
                    if ( $return_id > 0 ) {
                        my $return_info = get_return_info( $handler->{dbh}, $return_id );

                        # found an exchange
                        if ( $return_info->{exchange_shipment_id} ) {
                            my $shipment = $schema->resultset('Public::Shipment')->find($return_info->{exchange_shipment_id});
                            # exchange is on exchange hold - release it
                            if ( $shipment->shipment_status_id == $SHIPMENT_STATUS__EXCHANGE_HOLD ) {
                                $shipment->update_status(
                                    $SHIPMENT_STATUS__PROCESSING, $handler->{data}{operator_id}
                                );
                            }
                        }
                    }
                }

                # if status changed to 'cancelled' then remove any 'renumeration_tender' records
                if ( $handler->{param_of}{status_id} == $RENUMERATION_STATUS__CANCELLED ) {
                    my $renum   = $schema->resultset('Public::Renumeration')->find( $invoice_id );
                    my $renum_tenders   = $renum->renumeration_tenders;
                    while ( my $tender = $renum_tenders->next ) {
                        $tender->delete;
                    }
                }
            }

            # get renumeration items from post vars
            my %items = ();

            foreach my $form_field ( %{ $handler->{param_of} } ) {
                if ( $form_field =~ /^(price|tax|duty)-(\d+)/ ) {
                    $items{ $2 }{ $1 } = $handler->{param_of}{$form_field};
                }
            }

            # update invoice items if any were amended
            if ( keys(%items) ) {

                foreach my $item_id ( keys %items ) {

                    my $ship_item_id = $refund_item_info->{$item_id}{shipment_item_id};

                    # sanity checks when editing values
                    if ( $handler->{param_of}{status_id} != $RENUMERATION_STATUS__COMPLETED && $handler->{param_of}{status_id} != $RENUMERATION_STATUS__CANCELLED ) {
                        if ( ($items{$item_id}{price} - 0.1) > $shipment_item->{$ship_item_id}{unit_price} ){
                            die 'Unit Price of '. $items{$item_id}{price} .' greater than '. $shipment_item->{$ship_item_id}{unit_price} .' available to be refunded';
                        }
                        if ( ($items{$item_id}{tax} - 0.15) > $shipment_item->{$ship_item_id}{tax} ){
                            die 'Tax of '. $items{$item_id}{tax} .' greater than '. $shipment_item->{$ship_item_id}{tax} .' available to be refunded';
                        }
                        if ( ($items{$item_id}{duty} - 0.1) > $shipment_item->{$ship_item_id}{duty} ){
                            die 'Duty of '. $items{$item_id}{duty} .' greater than '. $shipment_item->{$ship_item_id}{duty} .' available to be refunded';
                        }
                    }

                    edit_invoice_item( $handler->{dbh}, $item_id, $items{$item_id}{price}, $items{$item_id}{tax} , $items{$item_id}{duty} );
                }
            }

            # get new invoice value for the change logging
            my $new_value = get_invoice_value($handler->{dbh}, $invoice_id);

            # if not cancelled then adjust any 'renumeration_tender' records with new values
            if ( $handler->{param_of}{status_id} != $RENUMERATION_STATUS__CANCELLED
                 && $refund_info->{renumeration_class_id} != $RENUMERATION_CLASS__GRATUITY ) {
                my $renum   = $schema->resultset('Public::Renumeration')->find( $invoice_id );
                adjust_existing_renum_tenders( $renum, $new_value );

                if ( $refund_info->{renumeration_type_id} == $RENUMERATION_TYPE__CARD_DEBIT ) {
                    # update order.tenders for Card Debits if the type of invoice is Card Debit
                    my $order_rec   = $schema->resultset('Public::Orders')->find( $order_id );
                    # $current_value - $new_value as Debits are negative so this way round is correct
                    if ( ( $current_value - $new_value ) > 0 ) {
                        # only edit if the value increases
                        update_card_tender_value( $order_rec, ( $current_value - $new_value ) );
                    }
                }
            }

            # log the change
            log_invoice_change($handler->{dbh}, $invoice_id, $current_value, $new_value, $handler->{data}{operator_id});
        }

        $guard->commit();
        $redirect_url .= '&action=View';
        xt_success('Invoice updated successfully.');
    };

    if ( my $err = $@ ) {
        xt_warn( $err );
        $redirect_url .= '&action=Edit';
    }

    return $handler->redirect_to( $redirect_url );
}

1;
