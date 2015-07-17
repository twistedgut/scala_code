package XTracker::Order::Actions::ChangeOrderStatus;

use strict;
use warnings;
use Try::Tiny;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database            qw( get_database_handle );

use XTracker::Database::Order;
use XTracker::Database::Customer;
use XTracker::Database::Address;
use XTracker::Database::Shipment  qw(:DEFAULT);
use XTracker::Database::Invoice;
use XTracker::Comms::FCP          qw( update_web_order_status );
use XTracker::Database::Channel   qw/get_channel_details/;
use XTracker::EmailFunctions;
use XTracker::Utilities           qw( parse_url number_in_list summarise_stack_trace_error );
use XTracker::WebContent::StockManagement;
use XTracker::Constants::FromDB qw/
    :order_status
    :shipment_status
    :shipment_item_status
    :shipment_hold_reason
    :renumeration_class
    :renumeration_status
    :correspondence_templates
    :pws_action
/;
use XTracker::Config::Local qw( customercare_email xtracker_email shipping_email config_var );
use XTracker::Error qw(xt_warn xt_success xt_info);
use XTracker::Logfile qw(xt_logger);
use XT::Net::Seaview::Client;
use XTracker::Order::Utils::StatusChange;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r, { dbh_type => q{schema} } );
    my $seaview     = XT::Net::Seaview::Client->new({schema => $handler->schema});
    my $status_change
      = XTracker::Order::Utils::StatusChange->new({schema => $handler->schema});

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);
    my $referer_details = $handler->parse_referer_url;

    # set up vars and get form data
    my $data;

    # CANDO-1485: Bulk log
    $data->{bulk_action_log_id} = $handler->{request}->param('bulk_action_log_id');

    $data->{action}             = $handler->{request}->param('action');
    $data->{order_id}           = $handler->{request}->param('order_id');
    $data->{cancel_reason_id}   = $handler->{request}->param('cancel_reason_id');
    $data->{refund_type_id}     = $handler->{request}->param('refund_type_id');
    $data->{send_email}         = $handler->{request}->param('send_email');
    $data->{email_from}         = $handler->{param_of}->{'email_from'};
    $data->{email_replyto}      = $handler->{param_of}->{'email_replyto'};
    $data->{email_to}           = $handler->{param_of}->{'email_to'};
    $data->{email_subject}      = $handler->{param_of}->{'email_subject'};
    $data->{email_body}         = $handler->{param_of}->{'email_body'};
    $data->{email_content_type} = $handler->{param_of}->{'email_content_type'};
    $data->{new_status_id}      = 0;
    $data->{order_nr}           = 0;
    $data->{new_website_status} = '';
    $data->{order_nr}           = '';

    # we need at least an order if and an action
    if ( !$data->{order_id} ) {
        die "No order id defined";
    }
    if ( !$data->{action} ) {
        die "No action defined";
    }


    # work out new status for order based on 'action'

    # placing order on credit hold
    if ( $data->{action} eq 'Hold' ) {
        $data->{new_status_id} = $ORDER_STATUS__CREDIT_HOLD;
        $section    = $referer_details->{section};
        $short_url  = $referer_details->{short_url};
    }
    # placing order on credit check from credit hold
    elsif ( $data->{action} eq 'Check' ) {
        $data->{new_status_id} = $ORDER_STATUS__CREDIT_CHECK;
        $section    = $referer_details->{section};
        $short_url  = $referer_details->{short_url};
    }
    # accepting order from credit check or hold
    elsif ( $data->{action} eq 'Accept' ) {
        $data->{new_status_id} = $ORDER_STATUS__ACCEPTED;
        $section    = $referer_details->{section};
        $short_url  = $referer_details->{short_url};
    }
    # cancelling order
    elsif ( $data->{action} eq 'Cancel' ) {
        $data->{new_status_id} = $ORDER_STATUS__CANCELLED;
    }


    # problem if we didn't match an action above
    if ( $data->{new_status_id} == 0 ) {
        die "Unknown action: $data->{action}";
    }


    my $stock_manager;
    eval {
        $handler->schema->txn_begin;

        # any refunds created via Cancellation will go
        # here where they can then be Refunded to the
        # Customer after the changes have been Committed
        my @refunds_created;
        my @messages_for_shipments;
        # get some order info
        $data->{order_info} = get_order_info($handler->{dbh}, $data->{order_id});
        $data->{channel}    = get_channel_details( $handler->{dbh}, $data->{order_info}{sales_channel} );
        $data->{shipments}  = get_order_shipment_info( $handler->{dbh}, $data->{order_id} );
        $data->{order_nr}   = $data->{order_info}{order_nr};

        # get correct from email addresses
        $data->{customercare_email}  = customercare_email( $data->{channel}{config_section} );
        $data->{xtracker_email}      = xtracker_email( $data->{channel}{config_section} );

        # order status update & log
        $status_change->change_order_status($data->{order_id},
                                            $data->{new_status_id},
                                            $handler->{data}{operator_id},
                                            $data->{bulk_action_log_id} );

        # extra actions for each type of update

        # credit hold
        if ( $data->{action} eq 'Hold' ) {
            # update status of all shipments
            $status_change->update_shipments_status($data->{shipments},
                                                    $SHIPMENT_STATUS__FINANCE_HOLD,
                                                    $handler->{data}{operator_id});

        }
        # credit check
        elsif ( $data->{action} eq 'Check' ) {

            # set a new status for website
            $data->{new_website_status} = "PENDING PAYMENT AUTHORISATION";

        }
        # accepting
        elsif ( $data->{action} eq 'Accept' ) {
            $data->{new_website_status} =  $status_change->accept_order(
                $data->{order_info},
                $data->{shipments},
                $data->{order_id},
                $handler->{data}{operator_id},
                { update_shipment_status_from_log => 1 },
            );
        }
        #  cancellation
        elsif ( $data->{action} eq "Cancel" ) {

            # set a new status for website
            $data->{new_website_status} = "CANCELLED";

            # cancel shipments, generate refunds and send emails if required
            $stock_manager = $handler->schema
                                     ->resultset('Public::Channel')
                                     ->find($data->{channel}{id})
                                     ->stock_manager;
            foreach my $shipment_id ( keys %{ $data->{shipments} } ) {
                my $return_hash = _cancel_shipment(
                    $handler,
                    $data,
                    $data->{shipments}{$shipment_id},
                    $stock_manager,
                    $handler->{data}{operator_id},
                );
                @refunds_created = @{$return_hash->{refunds}};
                push @messages_for_shipments ,$return_hash->{shipment_to_cancel}
                    if $return_hash->{shipment_to_cancel};
            }

            # Seaview welcome pack flag update - If the account is Seaview linked
            # and the order contains a welcome pack then the remote flag should be
            # set to false when the order is cancelled
            eval {
                my $order = $handler->schema
                                    ->resultset('Public::Orders')
                                    ->find($data->{order_id});

                my $account_urn = $seaview->registered_account($order->customer->id);
                if(defined $account_urn){
                    if($order->has_welcome_pack){
                        my $attempts = 0;
                        $seaview->update_welcome_pack_flag($account_urn,
                                                           0, # set flag to false
                                                           $attempts);
                    }
                }
            };
            if ( my $err = $@ ) {
                # Just log it and let it fail
                xt_logger->warn($err);
            }
        }

        if( $data->{channel}{dbh} ) {
            # commit any Web DB changes
            $data->{channel}{dbh}->commit();
        }
        $stock_manager->commit if $stock_manager;
        $handler->schema->txn_commit();

        ## Send ShipmentCancel message to IWS after the commit is DONE
        ## because we expect ShipmentReady response from IWS right away
        ## and when consuming it the shipment items statuses should be already changed in the DB.
        foreach my $shipment (@messages_for_shipments){
           $handler->msg_factory->transform_and_send( 'XT::DC::Messaging::Producer::WMS::ShipmentCancel', {shipment => $shipment});
        }

        if ( @refunds_created ) {
            my $failure_msg = "";
            my $fail_count  = 0;
            foreach my $refund ( @refunds_created ) {
                eval {
                    $handler->schema->txn_begin;
                    $refund->refund_to_customer( {
                                        refund_and_complete => 1,
                                        message_factory     => $handler->msg_factory,
                                        operator_id         => $handler->{data}{operator_id},
                                } );
                    $handler->schema->txn_commit();
                };
                if ( my $err = $@ ) {
                    $failure_msg    .= summarise_stack_trace_error( $err ) . '<br>';
                    $fail_count++;
                    $handler->schema->txn_rollback();
                }
            }
            if ( !$fail_count ) {
                xt_success( "Customer has also been Refunded" );
            }
            else {
                $failure_msg    =~ s/(<br>)*$//;
                xt_info(
                         "Customer has NOT been Refunded, because of " .
                         ( $fail_count > 1 ? "these failures" : "this failure" ) . ":<br>${failure_msg}<br><br>" .
                         ( $fail_count > 1 ? "These Refunds" : "This Refund" ) . " should now go to Finance to Complete"
                     );
            }
        }
    };

    if ( my $err = $@ ) {
        if( $data->{channel}{dbh} ) {
            # rollback any Web DB changes
            $data->{channel}{dbh}->rollback();
        }

        $stock_manager->rollback if $stock_manager;
        $handler->schema->txn_rollback();
        xt_warn( "Error: " . $err );
        return $handler->redirect_to( "$short_url/OrderView?order_id=$data->{order_id}" );
    }


    # the bit that sends the message to AMQ - at the moment we're sending to
    # AMQ AND updating via db handle - later this will be just one
    if ( $data->{action} eq "Cancel" ) {
        try {
            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::Orders::Update',
                {
                    order_id       => $data->{order_id},
                }
            );
        } catch {
            xt_warn( $_ );
        };
    }

    my $channel = $handler->schema->resultset('Public::Channel')->find($data->{channel}->{id});
    if ($data->{new_website_status} && $data->{order_nr} && !$channel->is_fulfilment_only) {

        # old annoying way to update status on order using direct
        # connection to db

        try {
            my $dbh_web = get_database_handle( { name => 'Web_Live_'.$data->{channel}{config_section}, type => 'transaction' } );
            update_web_order_status($dbh_web, { 'orders_id' => $data->{order_nr}, 'order_status' => $data->{new_website_status} } );
            $dbh_web->commit();
        } catch {
            xt_warn( $_ );
        };

    }

    if ( $section eq "Finance" ) {
        return $handler->redirect_to( "$short_url" );
    }
    else {
        return $handler->redirect_to( "$short_url/OrderView?order_id=$data->{order_id}" );
    }
}

sub _send_credit_check_email {

    my ($dbh, $order_id, $customercare_email, $operator_id) = @_;


    my $order_info                      = get_order_info($dbh, $order_id);
    $order_info->{invoice_address}      = get_address_info($dbh, $order_info->{invoice_address_id});
    $order_info->{channel}              = get_channel_details($dbh, $order_info->{sales_channel});
    $order_info->{customercare_email}   = $customercare_email;

    my $email_info = get_email_template( $dbh, $CORRESPONDENCE_TEMPLATES__CREDIT_CHECK__1, $order_info );

    my $email_sent = send_email( $customercare_email, $customercare_email, $order_info->{email}, 'Your order : '.$order_info->{order_nr}, $email_info->{content} );

    if ($email_sent == 1){
        log_order_email($dbh, $order_id, $CORRESPONDENCE_TEMPLATES__CREDIT_CHECK__1, $operator_id);
    }

    return $email_sent;
}

sub _cancel_shipment {
    my ($handler, $data_ref, $shipment_ref, $stock_manager, $operator_id) = @_;

    my $dbh     = $handler->{dbh};
    my $schema  = $handler->{schema};

    my $order   = $schema->resultset('Public::Orders')->find( $data_ref->{order_id} );

    my $shipment_items = get_shipment_item_info( $dbh, $shipment_ref->{id} );
    my $shipment = $schema->resultset('Public::Shipment')->find( $shipment_ref->{id} );

    # shipment already cancelled - do nothing
    return if $shipment_ref->{shipment_status_id} == $SHIPMENT_STATUS__CANCELLED;

    my @refunds;

    my $does_iws_know_about_me = $shipment->does_iws_know_about_me;

    update_shipment_status( $dbh, $shipment_ref->{id}, $SHIPMENT_STATUS__CANCELLED, $operator_id );

    # store credit refund required
    if ($data_ref->{refund_type_id} > 0){

        my $shipping        = 0;
        my $misc_refund     = 0;
        my $alt_customer    = 0;
        my $gift_credit     = 0;
        my $store_credit    = 0;  # GV: use 'orders.tender' records instead of '$shipment_ref->{store_credit} * -1';

        # work out the store credit value from 'orders.tender'
        # if there is a Voucher Credit used then this is
        # refunded as a Store Credit.
        my $store_credit_tender = $order->store_credit_tender;
        my $vouch_credit_tenders= $order->voucher_tenders;
        if ( $store_credit_tender ) {
            $store_credit   += $store_credit_tender->value;
        }
        if ( $vouch_credit_tenders->count ) {
            $store_credit   += $vouch_credit_tenders->get_column('value')->sum;
        }

        # create refund
        my $inv_id = create_invoice(
            $dbh, $shipment_ref->{id}, '', $data_ref->{refund_type_id}, $RENUMERATION_CLASS__CANCELLATION, $RENUMERATION_STATUS__AWAITING_ACTION, $shipping, $misc_refund, $alt_customer, $gift_credit, $store_credit, $data_ref->{order_info}{currency_id}
        );

        # create 'renumeration_tender' records for store credit and voucher credit tenders
        my $invoice = $schema->resultset('Public::Renumeration')->find( $inv_id );
        if ( $store_credit_tender ) {
            $invoice->create_related( 'renumeration_tenders',
                                            { tender_id => $store_credit_tender->id, value => $store_credit_tender->value } );
        }
        if ( $vouch_credit_tenders->count ) {
            my @vouch_credit_tenders    = $vouch_credit_tenders->all;
            foreach my $tender ( @vouch_credit_tenders ) {
                $invoice->create_related( 'renumeration_tenders',
                                                { tender_id => $tender->id, value => $tender->value } );
            }
        }

        log_invoice_status( $dbh, $inv_id, $RENUMERATION_STATUS__AWAITING_ACTION, $operator_id );
    }

    my @item_ids_actually_cancelled;

    # go through shipment items to cancel
    foreach my $shipment_item_id ( keys %{$shipment_items} ){
        my $si = $schema->resultset('Public::ShipmentItem')->find( $shipment_item_id );
        next unless $si->can_cancel;
            # If we actually do cancel a shipment item and this is part of a
            # preorder, we need to do some refunds later, so we store the ids
            # in an array
         my $cancelled_si = $si->cancel({
            operator_id            => $operator_id,
            customer_issue_type_id => $data_ref->{cancel_reason_id},
            pws_action_id          => $PWS_ACTION__CANCELLATION,
            notes                  => "Change Order Status $data_ref->{action} order_id: $data_ref->{order_id}",
            stock_manager          => $stock_manager,
        });
        push @item_ids_actually_cancelled, $cancelled_si->id if $cancelled_si;
    }

    # customer email - if required
    if ($data_ref->{send_email} eq 'yes'){

        my $email_sent  = send_customer_email( {
            to              => $data_ref->{email_to},
            from            => $data_ref->{email_from},
            replyto         => $data_ref->{email_replyto},
            subject         => $data_ref->{email_subject},
            content         => $data_ref->{email_body},
            content_type    => $data_ref->{email_content_type}
        } );


        if ($email_sent == 1){
            log_order_email($dbh, $data_ref->{order_id}, $CORRESPONDENCE_TEMPLATES__CONFIRM_CANCELLED_ORDER, $operator_id);
        }
    }

    if ( $order->has_preorder ) {
        # if this was for a Pre-Order then Create a Refund
        my $refund  = $shipment->pre_order_create_cancellation_card_refund( \@item_ids_actually_cancelled, $operator_id );
        push @refunds, $refund          if ( $refund );
        xt_success( "Order Cancelled" );
    }
    else {
        # cancel the Order Payment's Pre-Auth if there is one
        my $result = $order->cancel_payment_preauth( {
                                                context => 'Cancelling an Order',
                                                operator_id => $operator_id,
                                            } );
        if ( defined $result ) {
            # if the result is defined then there was a payment
            if ( $result->{success} ) {
                xt_success( "Order & Payment Card Authorisation Cancelled" );
            }
            elsif ( $result->{error} == 1 ) {
                # only worth reporting on level 1 errors
                xt_info( "This Order has been Cancelled, However a problem has occured whilst attempting to cancel the Payment Card Authorisation, PLEASE notify Online Fraud of this Failure.<br/><br/>Failure Reason: ".$result->{message} );
            }
            else {
                # there were only level 2 errors which we don't care about here
                xt_success( "Order Cancelled" );
            }
        }
        else {
            xt_success( "Order Cancelled" );
        }
    }

    return {refunds => \@refunds, shipment_to_cancel => ($does_iws_know_about_me ? $shipment : undef )};
}

1;
