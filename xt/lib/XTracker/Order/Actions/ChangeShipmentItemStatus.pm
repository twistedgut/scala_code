package XTracker::Order::Actions::ChangeShipmentItemStatus;

use strict;
use warnings;
use Try::Tiny;

use XTracker::Handler;
use XTracker::Database::Channel qw( get_channels );
use XTracker::Database::Order;
use XTracker::Database::Shipment qw(:DEFAULT);
use XTracker::Database::Address;
use XTracker::Database::Invoice      qw( :DEFAULT update_card_tender_value );
use XTracker::Database::OrderPayment qw( check_order_payment_fulfilled );

use XTracker::EmailFunctions;
use XTracker::Utilities qw( parse_url number_in_list summarise_stack_trace_error );
use XTracker::Constants::FromDB qw( :correspondence_templates :shipment_item_status :pws_action );
use XTracker::Error qw(xt_warn xt_success xt_info);
use XTracker::Config::Local qw( config_var );
use XTracker::WebContent::StockManagement;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    # set up vars and get query string data
    my $order_id    = $handler->{param_of}{order_id};
    my $shipment_id = $handler->{param_of}{shipment_id};
    my $redirect_url   = $short_url.'/OrderView?order_id='.$order_id;

    my $schema = $handler->{schema};
    my $dbh    = $schema->storage->dbh;
    my $shipment  = $schema->resultset('Public::Shipment')->find($shipment_id);
    my $order_obj = $shipment->order;

    # any refund created via Cancellation will go
    # here where it can then be Refunded to the
    # Customer after the changes have been Committed
    my $refund_created;

    # hash to keep track of items changed
    my %change_items = ();

    # shipment item id passed in URL
    if ( $handler->{param_of}{shipment_item_id} ) {
        $change_items{ $handler->{param_of}{shipment_item_id} } = 1;
    }
    # no item id in URL - check post variables for a form submission
    else {
        foreach my $form_key ( %{ $handler->{param_of} } ) {
            if ( $form_key =~ m/-/ ) {
                my ($field_name, $item_id) = split /-/, $form_key;
                # item field
                if ( $field_name eq 'item' && $handler->{param_of}{$form_key} == 1 ) {
                    $change_items{ $item_id } = 1;
                }
            }
        }
    }

    my $stock_manager = $order_obj->channel->stock_manager;
    eval {
        # Let's break from this eval if we have no items to work on...
        # Apologies for the die used in such a way, but I don't know of a
        # better way to break from an eval :( It would actually be nice to
        # redirect here before the eval, but we still do stuff in the handler
        # even though we have no updates to do (is this a wtf)?
        die q{} unless %change_items;

        # any extra Success messages will be put in this variable
        my $extra_success_msg = '';

        # get shipment items from db to validate current status against new
        my $shipment_items = get_shipment_item_info( $dbh, $shipment_id );

        # for those Shipment Item Ids that do get Cancelled
        my @cancel_item_ids;
        my $guard = $schema->txn_scope_guard;
        my $total_amount_cancelled = 0;
        foreach my $shipment_item_id ( keys %change_items ) {
            my $ship_item = $shipment->find_related('shipment_items', $shipment_item_id );

            # This looks like it checks that we haven't marked the wrong item
            # in a shipment where we have > 1 of the same variant?
            my $variant_ship_items_rs = $shipment->search_related('shipment_items',{variant_id => $ship_item->variant_id});
            while (my $item = $variant_ship_items_rs->next){
                last if $ship_item->is_incomplete_pick;
                next if $item->id == $shipment_item_id;
                next unless $item->is_incomplete_pick;
                ## see if this incomplete pick item will not be cancelled
                #   this means that CC cancelled the wrong one
                next if defined $change_items{$item->id};
                $item->update({is_incomplete_pick => 0});
                $ship_item->update({is_incomplete_pick => 1});
            }

            # record cancellations in cancelled_item table
            my $reason_id = $handler->{param_of}{ 'reason-'.$shipment_item_id };
            # If we actually do cancel a shipment item and this is part of a
            # preorder, we need to do some refunds later, so we store the ids
            # in an array
            my $cancelled_si = $ship_item->cancel({
                customer_issue_type_id => $reason_id,
                operator_id => $handler->operator_id,
                pws_action_id => $PWS_ACTION__CANCELLATION,
                notes => "Cancel item $shipment_item_id",
                stock_manager => $stock_manager,
                no_allocate => 1,
            });
            if ( $cancelled_si ) {
                $total_amount_cancelled += $cancelled_si->purchase_price;
                push @cancel_item_ids, $cancelled_si->id;
            }
        }

        # may need to adjust shipping charge
        # default value of shipping refund to 0
        my $shipping_refund = 0;

        # possible shipping charge adjustments
        my $shipment_info       = get_shipment_info( $dbh, $shipment_id );
        my $shipment_address    = get_address_info( $dbh, $shipment_info->{shipment_address_id} );
        my $order_info          = get_order_info( $dbh, $order_id );

        if ( $shipment_info->{shipping_charge} > 0 ) {

            # International order - changes to shipping may be needed
            if ( $shipment_info->{type} eq 'International' || $shipment_info->{type} eq 'International DDU' ) {

                my $num_items = (keys %{$shipment_items}) - (keys %change_items);

                # get new shipping charge info
                my %shipping_param = (
                        country             => $shipment_address->{country},
                        county              => $shipment_address->{county},
                        postcode            => $shipment_address->{postcode},
                        item_count          => $num_items,
                        order_total         => 0,   #If it wasn't >1000 before, it won't be now
                        order_currency_id   => $order_info->{currency_id},
                        shipping_charge_id  => $shipment_info->{shipping_charge_id},
                        shipping_class_id   => $shipment_info->{shipping_class_id},
                        channel_id          => $order_info->{channel_id},
                );

                my $new_shipping = calc_shipping_charges($dbh, \%shipping_param);

                # work out how much to refund
                $shipping_refund = $shipment_info->{shipping_charge} - $new_shipping->{charge};
            }
        }

        # adjust shipment shipping charge if neccessary
        if ($shipping_refund > 0){
            my $new_charge = $shipment_info->{shipping_charge} - $shipping_refund;
            update_shipment_shipping_charge( $dbh, $shipment_id, $new_charge);

            $total_amount_cancelled += $shipping_refund;
        }

        # invalidate payment pre-auth if one exists for order and not fulfilled yet
        if (check_order_payment_fulfilled($dbh, $order_id) == 0){
            if ( $total_amount_cancelled > 0 ) {
                my $decrease_amount = $total_amount_cancelled * -1;    # flip, so that it's appropriate to decrease the tender value
                update_card_tender_value( $order_obj, $decrease_amount );
            }

            my $result = $shipment->discard_changes->notify_psp_of_basket_changes_or_cancel_payment( {
                context     => "Cancelling Items",
                operator_id => $handler->{data}{operator_id},
            } );
            if ( $result->{payment_deleted} ) {
                my $replaced_payment = $order_obj->replaced_payments->order_by_id_desc->first;
                $extra_success_msg = "'" . $replaced_payment->payment_method_name . "' payment has been removed " .
                                     "because it is no longer needed to pay for the Order";
            }
            else {
                $order_obj->invalidate_order_payment();
            }
        }

        # cancellation email if required
        if ( $handler->{param_of}{send_email} eq 'yes' ){

            # TODO: It looks like this email gets sent even if we later
            # die/roll back... the email to the customer should really be sent
            # as the last thing we do in this transaction
            my $email_sent = send_customer_email( {
                to           => $handler->{param_of}{email_to},
                from         => $handler->{param_of}{email_from},
                reply_to     => $handler->{param_of}{email_replyto},
                subject      => $handler->{param_of}{email_subject},
                content      => $handler->{param_of}{email_body},
                content_type => $handler->{param_of}{email_content_type}
            } );

            if ($email_sent == 1){
                log_shipment_email( $dbh, $shipment_id, $CORRESPONDENCE_TEMPLATES__CONFIRM_CANCELLED_ITEM, $handler->{data}{operator_id} );
            }
        }

        # If Shipment is now a Virtual Voucher only Order it can be dispatched
        if ( $shipment->discard_changes->is_virtual_voucher_only ) {
            # if Virtual Voucher Only order ZERO Shipping Charge
            $shipment->update( { shipping_charge => 0 } );

            if ( $shipment->dispatch_virtual_voucher_only_shipment( $handler->operator_id ) ) {
                xt_success( "Virtual Voucher Only Order was Dispatched" );
            }
        }

        if ( @cancel_item_ids && $order_obj->has_preorder ) {
            $refund_created = $shipment->pre_order_create_cancellation_card_refund( \@cancel_item_ids, $handler->operator_id );
        }
        $stock_manager->commit;
        $guard->commit;

        if ( @cancel_item_ids ) {

            # Re-allocate outside the transaction to make sure we can handle allocate response
            $shipment->allocate({operator_id => $handler->operator_id});

            xt_success( sprintf
                'Shipment item%s been cancelled', @cancel_item_ids > 1 ? 's have' : ' has'
            );
        }

        xt_success( $extra_success_msg )    if ( $extra_success_msg );
    };
    if ( my $err = $@ ) {
        $stock_manager->rollback;
        xt_warn("An error occured trying to update item status:<br />$err");
    }

    # I have no idea why we the following try/catch blocks aren't done in the
    # eval above... surely we want to either do everything in this module or
    # nothing?
    try {
        $handler->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::Orders::Update',
            {
                order_id       => $order_id,
            }
        );

        if ($shipment->discard_changes->does_iws_know_about_me) {
            # we asked for physical items, then canceled all
            # of them: as far as IWS is concerned, we canceled
            # the shipment
            my $msg = $shipment->is_virtual_voucher_only
                    ? 'XT::DC::Messaging::Producer::WMS::ShipmentCancel'
                    : 'XT::DC::Messaging::Producer::WMS::ShipmentRequest';

            if (!config_var('PRL', 'rollout_phase')) {
                $handler->msg_factory->transform_and_send($msg, $shipment );
            }
        }
    } catch {
        xt_warn( $_ );
    };

    if ( $refund_created ) {
        # if a Refund was created then try and
        # Auto-Refund it back to the Customer
        my $ok  = 1;
        try {
            my $guard = $schema->txn_scope_guard;
            $refund_created->refund_to_customer( {
                                refund_and_complete => 1,
                                message_factory     => $handler->msg_factory,
                                operator_id         => $handler->{data}{operator_id},
                        } );
            $guard->commit;
        } catch {
            my $failure_message = summarise_stack_trace_error( $_ );
            $failure_message    =~ s/(<br>)*$//;
            xt_info( "Customer has NOT been Refunded, because of this failure:<br>${failure_message}<br><br>This Refund should now go to Finance to Complete" );
            $ok = 0;
        };
        if ( $ok ) {
            xt_success( "Customer has also been Refunded" );
        }
    }

    return $handler->redirect_to( $redirect_url );
}

1;
