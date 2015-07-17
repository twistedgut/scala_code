package XTracker::Order::Actions::UpdateShipmentPricing;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Invoice         qw( :DEFAULT create_renum_tenders_for_refund update_card_tender_value );
use XTracker::Database::OrderPayment    qw( check_order_payment_fulfilled);

use XTracker::Utilities qw( parse_url );
use XTracker::EmailFunctions;
use XTracker::Constants::FromDB qw( :correspondence_templates :renumeration_class :renumeration_status :renumeration_type );
use XTracker::DBEncode  qw( encode_it );

use XTracker::Error;


sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    my $data;

    # get shipment id from url
    my $shipment_id = $handler->{request}->param('shipment_id');

    # form submitted
    if ( $handler->{request}->param('submit') ) {

        eval {
            my $schema  = $handler->schema;
            my $dbh     = $schema->storage->dbh;

            my $guard = $schema->txn_scope_guard;
            $data->{shipment}       = get_shipment_info( $dbh, $shipment_id );
            $data->{order}          = get_order_info( $dbh, $data->{shipment}{orders_id} );
            $data->{shipment_item}  = get_shipment_item_info( $dbh, $shipment_id );
            $data->{total}          = 0;
            my $order               = $schema->resultset('Public::Orders')->find( $data->{shipment}{orders_id} );

            # collect shipment_item pricing and build up refund data
            foreach my $item_id ( keys %{ $data->{shipment_item} } ) {
                if ( $handler->{request}->param('price_'.$item_id) ){
                    $data->{amend_item}{$item_id}{price}    = $handler->{request}->param('price_'.$item_id);
                    $data->{amend_item}{$item_id}{tax}      = $handler->{request}->param('tax_'.$item_id);
                    $data->{amend_item}{$item_id}{duty}     = $handler->{request}->param('duty_'.$item_id);

                    $data->{amend_item}{$item_id}{diff_price}   = $data->{shipment_item}{$item_id}{unit_price} - $handler->{request}->param('price_'.$item_id);
                    $data->{amend_item}{$item_id}{diff_tax}     = $data->{shipment_item}{$item_id}{tax} - $handler->{request}->param('tax_'.$item_id);
                    $data->{amend_item}{$item_id}{diff_duty}    = $data->{shipment_item}{$item_id}{duty} - $handler->{request}->param('duty_'.$item_id);
                }
            }

            # shipping changes
            if ( $handler->{request}->param('shipping') ){
                $data->{amend_shipping}         = $handler->{request}->param('shipping');
                $data->{amend_diff_shipping}    = $data->{shipment}{shipping_charge} - $handler->{request}->param('shipping');
            }
            else {
                $data->{amend_diff_shipping} = 0;
            }



            # do database updates

            # update item pricing
            foreach my $item_id ( keys %{ $data->{amend_item} } ) {
                update_shipment_item_pricing($dbh, $item_id, $data->{amend_item}{$item_id}{price}, $data->{amend_item}{$item_id}{tax}, $data->{amend_item}{$item_id}{duty});
            }

            # update shipping charge
            if ($data->{amend_shipping}){
                update_shipment_shipping_charge($dbh, $shipment_id, $data->{amend_shipping});
            }



            # Datacash Payment has been fulfilled - create new payment
            if (check_order_payment_fulfilled($dbh, $data->{shipment}{orders_id})){

                # create refund/debit
                if ( $handler->{request}->param('refund_type') > 0){
                        my $refund_type = $handler->{request}->param('refund_type');

                        my $diff_total  = $data->{amend_diff_shipping};

                        my $inv_id = create_invoice(
                                $dbh,
                                $shipment_id,
                                '',
                                $handler->{request}->param('refund_type'),
                                $RENUMERATION_CLASS__ORDER,
                                $RENUMERATION_STATUS__AWAITING_ACTION,
                                $data->{amend_diff_shipping},
                                0,
                                0,
                                0,
                                0,
                                $data->{order}{currency_id}
                        );

                        log_invoice_status( $dbh, $inv_id, $RENUMERATION_STATUS__AWAITING_ACTION, $handler->{data}{operator_id} );

                        foreach my $item_id ( keys %{ $data->{amend_item} } ) {
                            create_invoice_item(
                                        $dbh,
                                        $inv_id,
                                        $item_id,
                                        $data->{amend_item}{$item_id}{diff_price},
                                        $data->{amend_item}{$item_id}{diff_tax},
                                        $data->{amend_item}{$item_id}{diff_duty}
                                    );

                            $diff_total += $data->{amend_item}{$item_id}{diff_price} +
                                           $data->{amend_item}{$item_id}{diff_tax} +
                                           $data->{amend_item}{$item_id}{diff_duty};
                        }

                        if ( $refund_type != $RENUMERATION_TYPE__CARD_DEBIT && $diff_total != 0 ) {
                            my $renum   = $schema->resultset('Public::Renumeration')->find( $inv_id );
                            create_renum_tenders_for_refund( $order, $renum, $diff_total );
                        }

                        # at this stage we will only increase the orders.tender value
                        # for Card Debits not decrease which is safer for making returns
                        if ( $refund_type == $RENUMERATION_TYPE__CARD_DEBIT ) {
                            update_card_tender_value( $order, ( $diff_total * -1 ) );
                        }
                }

            }
            # Datacash Payment has NOT been fulfilled - invalidate pre-auth
            else {
                # loop through differences
                my $diff_total  = $data->{amend_diff_shipping};
                foreach my $item_id ( keys %{ $data->{amend_item} } ) {
                    $diff_total += $data->{amend_item}{$item_id}{diff_price} +
                                   $data->{amend_item}{$item_id}{diff_tax} +
                                   $data->{amend_item}{$item_id}{diff_duty};
                }
                # update original card 'orders.tender' value
                if ( $diff_total != 0 ) {
                    $diff_total *= -1;  # flip, so that it's appropriate to increase/decrease the tender value
                    update_card_tender_value( $order, $diff_total );
                }

                my $shipment_obj = $order->discard_changes->shipments->find( $shipment_id );
                my $result = $shipment_obj->notify_psp_of_basket_changes_or_cancel_payment( {
                    context     => "Amend Pricing",
                    operator_id => $handler->{data}{operator_id},
                } );
                if ( $result->{payment_deleted} ) {
                    my $replaced_payment = $order->replaced_payments->order_by_id_desc->first;
                    xt_success( "Prices have been Amended and the '" . $replaced_payment->payment_method_name . "' payment has been removed" );
                }
                else {
                    $order->invalidate_order_payment();
                    xt_success( "Prices have been Amended" );
                }
            }

            ### customer email - if required
            if ( ( $handler->{request}->param('send_email') // '') eq 'yes' ) {

                my $email_sent = send_customer_email({
                    from        => $handler->{param_of}->{'email_from'},
                    reply_to    => $handler->{param_of}->{'email_replyto'},
                    to          => $handler->{param_of}->{'email_to'},
                    subject     => $handler->{param_of}->{'email_subject'},
                    content     => $handler->{param_of}->{'email_body'}
                });

                if ($email_sent == 1) {
                    # BUG: http://jira4.nap/browse/FLEX-604
                    log_shipment_email($dbh, $shipment_id, $CORRESPONDENCE_TEMPLATES__CONFIRM_PRICE_CHANGE__1, $handler->{data}{operator_id});
                }
            }

            $guard->commit();
        };

        if (my $error = $@) {
            $r->print(encode_it($error));
            return OK;
        }
    }

    return $handler->redirect_to( "$short_url/OrderView?order_id=$data->{shipment}{orders_id}" );
}

1;

