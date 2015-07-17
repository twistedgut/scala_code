package XTracker::Order::Actions::UpdateShipment;

use strict;
use warnings;

use Perl6::Export::Attrs;
use List::Util qw/ first /;
use XTracker::Schema::Row::Delta::Shipment;

use XTracker::Handler;
use XTracker::Logfile qw(xt_logger);

use XTracker::Database::Order;
use XTracker::Database::Invoice     qw( :DEFAULT create_renum_tenders_for_refund update_card_tender_value );
use XTracker::Database::Customer;
use XTracker::Database::Address;
use XTracker::Database::Shipment    qw(
    get_shipping_charge_data delete_print_log
    get_shipment_shipping_account
    set_shipment_shipping_account
    :DEFAULT
    :carrier_automation
);
use XT::Data::DateTimeFormat qw/ web_format_from_datetime /;
use XT::Data::NominatedDay::Shipment;

use XTracker::Order::Functions::Shipment::EditShipment qw/
    get_shipment_stage
    is_shipment_selected_yet
    fetch_available_nominated_delivery_dates_from_website
/;

use XTracker::Config::Local         qw( :carrier_automation config_var );
use XTracker::Database::Logging     qw( :carrier_automation );

use XTracker::Database::OrderPayment qw(check_order_payment_fulfilled);

use XTracker::Order::Printing::ShippingInputForm;
use XTracker::Order::Printing::PremierShipmentInfo;
use XTracker::Order::Printing::PremierDeliveryNote;

use XTracker::Utilities qw( parse_url url_encode number_in_list );
use XTracker::Constants::FromDB qw( :shipment_type :shipment_status :renumeration_type :renumeration_class :renumeration_status :shipment_item_status );
use XTracker::Error;

sub handler {
    ## no critic(ProhibitDeepNests)
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    my $redir_form  = 0;

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    my $shipment_id = $handler->{param_of}{shipment_id};
    my $order_id    = $handler->{param_of}{order_id};
    my $redirect    = $short_url.'/OrderView?order_id='.$order_id;

    my $schema      = $handler->schema;
    my $order       = $schema->resultset('Public::Orders')->find( $order_id );

    # shipment id in post vars?
    return $handler->redirect_to( $redirect ) unless $shipment_id;

    # get the shipment object once.
    my $shipment = $schema->resultset('Public::Shipment')->find( $shipment_id );

    my $shipment_notes_delta = XTracker::Schema::Row::Delta::Shipment->new({
        dbic_row    => $shipment,
        operator_id => $handler->operator_id,
    });

    eval {

        my $dbh = $schema->storage->dbh;
        my $guard = $schema->txn_scope_guard;
        # get shipment data
        my $shipment_info   = get_shipment_info( $dbh, $shipment_id );
        my $shipment_address= get_address_info( $schema, $shipment_info->{shipment_address_id} );
        my $shipment_items  = get_shipment_item_info( $dbh, $shipment_id );
        my $order_info      = get_order_info( $dbh, $order_id );
        my $old_rtcb_state  = $shipment_info->{real_time_carrier_booking};
        # find out if carrier automation is possible before any changes are made
        my $orig_isautoable = autoable( $schema, { mode => 'isit', shipment_id => $shipment_id, operator_id => $handler->operator_id } );
        # get channel record for shipment
        my $channel         = $schema->resultset('Public::Channel')->find( $order_info->{channel_id} );

        # re-direct to Invalid Shipments page if that is where you have come from
        if ( $subsection =~ /^(Invalid Shipments)$/ ) {
            $redirect   = $short_url."?show_channel=".$order_info->{channel_id};
        }

        # check carrier automation has a reason
        if ( exists $handler->{param_of}{rtcb} ) {
            if  ( ( $handler->{param_of}{rtcb} != $shipment_info->{real_time_carrier_booking} )
                && ( $handler->{param_of}{rtcb_reason} eq "" ) ) {

                $redirect   = $short_url.'/EditShipment?order_id='.$order_id.'&shipment_id='.$shipment_id;
                xt_warn("A Change to Carrier Automation MUST have a Reason");
                $redir_form = 1;
                die "No Reason Given";
            }
        }


        # use existing gift info if not available from form
        if ($handler->{param_of}{gift} eq '') {
            $handler->{param_of}{gift} = $shipment_info->{gift};
            $handler->{param_of}{gift_msg} = $shipment_info->{gift_msg};
        };

        # only update gift message if it has changed
        my $gms = $shipment->get_gift_messages();

        foreach my $gm (@$gms) {
            if (!defined($gm->shipment_item)) {
                # this is the top level gift message that we can change.
                if ($handler->{param_of}{gift_msg} ne $gm->get_message_text()) {
                    $gm->replace_existing_image();
                }
            }
        }

        # update shipment info
        $shipment->update({
                email => $handler->{param_of}{email},
                telephone => $handler->{param_of}{telephone},
                mobile_telephone => $handler->{param_of}{mobile_telephone},
                packing_instruction => $handler->{param_of}{packing_instruction},
                gift => $handler->{param_of}{gift},
                gift_message => $handler->{param_of}{gift_msg},
            });



        # shipping charge changed?
        if ( $handler->{param_of}{shipping_charge_id} && ( $handler->{param_of}{shipping_charge_id} != $shipment_info->{shipping_charge_id} ) ) {

            update_shipment_shipping_charge_id( $dbh, $shipment_id, $handler->{param_of}{shipping_charge_id} );

            my $shipping_charge_data = get_shipping_charge_data( $dbh, $handler->{param_of}{shipping_charge_id} );

            # have we switched to Premier from non-Premier ?
            if ( $shipping_charge_data->{class} eq 'Same Day' && $shipment_info->{type} ne 'Premier' ){
                update_shipment_type( $dbh, $shipment_id, $SHIPMENT_TYPE__PREMIER );
                $shipment_info->{shipment_type_id} = $SHIPMENT_TYPE__PREMIER;
            }

            # have we switched from Premier to non-Premier ?
            if ( $shipping_charge_data->{class} ne 'Same Day' && $shipment_info->{type} eq 'Premier' ) {
                update_shipment_type( $dbh, $shipment_id, $SHIPMENT_TYPE__DOMESTIC );
                $shipment_info->{shipment_type_id} = $SHIPMENT_TYPE__DOMESTIC;
            }

            # have we switched between shipping accounts?
            my $shipping_account_id = get_shipment_shipping_account(
                $dbh,
                {
                    channel_id          => $order_info->{channel_id},
                    shipment_type_id    => $shipment_info->{shipment_type_id},
                    country             => $shipment_address->{country},
                    postcode            => $shipment_address->{postcode},
                    item_data           => $shipment_items,
                    shipping_class      => $shipping_charge_data->{class},
                }
            );

            if ( $shipping_account_id != $shipment_info->{shipping_account_id} ) {
                set_shipment_shipping_account( $dbh, $shipment_id, $shipping_account_id );
            }


            # update shipping charge option selected by user
            if ( ( $handler->{param_of}{update_shipping_charge} // 0 ) == 1 ) {

                # get new shipping charge for shipment
                my $shipment_total  = 0;
                my $item_count      = 0;

                # loop through shipment items to get shipment total & item count
                foreach my $item_id ( keys %{ $shipment_items } ) {
                    # only active items included
                    if (number_in_list($shipment_items->{$item_id}{shipment_item_status_id},
                                        $SHIPMENT_ITEM_STATUS__NEW,
                                        $SHIPMENT_ITEM_STATUS__SELECTED,
                                        $SHIPMENT_ITEM_STATUS__PICKED,
                                        $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                        $SHIPMENT_ITEM_STATUS__PACKED,
                                    ) ) {
                        $shipment_total += $shipment_items->{$item_id}{unit_price} + $shipment_items->{$item_id}{tax} + $shipment_items->{$item_id}{duty};
                        $item_count++;
                    }
                }

                my $new_shipping = calc_shipping_charges(
                        $dbh,
                        {
                            country             => $shipment_address->{country},
                            county              => $shipment_address->{county},
                            postcode            => $shipment_address->{postcode},
                            item_count          => $item_count,
                            order_total         => $shipment_total,
                            order_currency_id   => $order_info->{currency_id},
                            shipping_charge_id  => $handler->{param_of}{shipping_charge_id},
                            shipping_class_id   => $shipment_address->{shipping_class_id},
                            channel_id          => $order_info->{channel_id},
                        }
                );


                # do we need to amend shipping charge?
                if ( $shipment_info->{shipping_charge} != $new_shipping->{charge} ) {

                    # if payment already taken we'll need to create a new credit/debit
                    if ( check_order_payment_fulfilled( $dbh, $order_id ) ){

                        # difference between shipping charges
                        my $shipping_diff = $shipment_info->{shipping_charge} - $new_shipping->{charge};

                        # difference greater than 3??
                        if ($shipping_diff > 3 || $shipping_diff < -3) {

                            # refund or debit?
                            my $renum_type_id;

                            # debit
                            if ($shipping_diff < 0) {
                                $renum_type_id = $RENUMERATION_TYPE__CARD_DEBIT;
                            }
                            # credit
                            else {
                                $renum_type_id = $RENUMERATION_TYPE__CARD_REFUND;
                            }

                            my $inv_id = create_invoice(
                                            $dbh,
                                            $shipment_id,
                                            '',
                                            $renum_type_id,
                                            $RENUMERATION_CLASS__ORDER,
                                            $RENUMERATION_STATUS__AWAITING_ACTION,
                                            $shipping_diff,
                                            0, # misc refund
                                            0, # alt customer number
                                            0, # gift credit
                                            0, # store credit
                                            $order_info->{currency_id}
                            );

                            log_invoice_status( $dbh, $inv_id, $RENUMERATION_STATUS__AWAITING_ACTION, $handler->{data}{operator_id} );

                            if ( $renum_type_id == $RENUMERATION_TYPE__CARD_REFUND && $shipping_diff != 0 ) {
                                my $invoice = $schema->resultset('Public::Renumeration')->find( $inv_id );
                                create_renum_tenders_for_refund( $order, $invoice, $shipping_diff );
                            }

                            # at this stage we will only increase the orders.tender value
                            # for Card Debits not decrease which is safer for making returns
                            if ( $renum_type_id == $RENUMERATION_TYPE__CARD_DEBIT ) {
                                update_card_tender_value( $order, ( $shipping_diff * -1 ) );
                            }
                        }
                        else {
                            # even if the difference is less than -3
                            # still need to apply to orders.tender for Card Debits

                            if ( $shipping_diff < 0 ) {
                                # at this stage we will only increase the orders.tender value
                                # for Card Debits not decrease which is safer for making returns
                                update_card_tender_value( $order, ($shipping_diff * -1 ) );
                            }
                        }
                    }
                    # Payment has NOT been fulfilled - just invalidate pre-auth
                    else {
                        my $shipping_diff   = $shipment_info->{shipping_charge} - $new_shipping->{charge};

                        # update original card 'orders.tender' value
                        if ( $shipping_diff != 0 ) {
                            $shipping_diff *= -1;  # flip, so that it's appropriate to increase/decrease the tender value
                            update_card_tender_value( $order, $shipping_diff );
                        }

                        update_shipment_shipping_charge( $dbh, $shipment_id, $new_shipping->{charge} );

                        my $result = $shipment->discard_changes->notify_psp_of_basket_changes_or_cancel_payment( {
                            context     => "Update Shipping Charge",
                            operator_id => $handler->{data}{operator_id},
                        } );
                        if ( $result->{payment_deleted} ) {
                            my $replaced_payment = $order->replaced_payments->order_by_id_desc->first;
                            xt_success( "Shipping Charge has been changed and the '" . $replaced_payment->payment_method_name . "' payment has been removed" );
                        }
                        else {
                            $order->invalidate_order_payment();
                            xt_success("Shipping Charge has been changed");
                        }
                    }
                }
            }

            # phew. Update SLAs just in case
            $shipment->discard_changes->apply_SLAs;
        }

        update_nominated_day(
            $shipment_info->{shipping_charge_id},          # previous shipping_charge_id
            $handler->{param_of}{nominated_delivery_date}, # new delivery date
            $shipment,
            $shipment_items,
            $shipment_address,
        );

        # In the new world, setting the rtcb here means forcing manual booking
        # - the parameter name and template will change once we make the rest
        # of the changes to consolidate booking automation across carriers
        $shipment->update({force_manual_booking => $handler->{param_of}{rtcb} ? 0 : 1})
            if exists $handler->{param_of}{rtcb};

        # get a possible change in whether carrier automation can happen by any updating of Shipment Type
        my $new_isautoable  = autoable( $schema, { mode => 'isit', shipment_id => $shipment_id, operator_id => $handler->operator_id } );
        if ( !$new_isautoable || $new_isautoable != $orig_isautoable || $channel->carrier_automation_is_off ) {
            # if you can't use carrier automation now or you couldn't then but you can now then change the rtcb field accordingly
            # also if carrier automation is off for the shipment's sales channel then force a deduce as well
            autoable( $schema, { mode => 'deduce', shipment_id => $shipment_id, operator_id => $handler->operator_id } );
        }

        # check rtcb field hasn't changed due to Shipment Type change also can only change rtcb if carrier automation is allowed
        if ( $new_isautoable && $new_isautoable == $orig_isautoable && exists $handler->{param_of}{rtcb} && $channel->carrier_automation_is_on ) {
            # only change rtcb field if it remains unchanged from original and the new state is different
            if ( $handler->{param_of}{rtcb} != $old_rtcb_state ) {
                set_carrier_automated( $dbh, $shipment_id, $handler->{param_of}{rtcb} );
                log_shipment_rtcb(  $dbh,
                                    $shipment_id,
                                    $handler->{param_of}{rtcb},
                                    $handler->{data}{operator_id},
                                    $handler->{param_of}{rtcb_reason} );
            }
        }

        # re-generating Shipping input form
        if ( $handler->{param_of}{regen_shipping_input} ) {

            # delete old form from DB
            delete_print_log( $dbh, $handler->{param_of}{regen_shipping_input} );

            # create new one!
            generate_input_form( $shipment_id, 'Shipping' );

        }

        # print off Premier paperwork
        if ( $handler->{param_of}{regen_premier} ) {

            generate_premier_info($dbh, $shipment_id, 'Premier Shipping', 1);
            generate_premier_delivery_note($dbh, $shipment_id, 'Premier Shipping', 1);

        }

        # send updated shipment request message to WMS
        # Only re-send the shipment_request message if we're in an
        # automated env (i.e. DC1 for now) and IWS already knows about
        # the shipment. Don't send in DC2 because they really really
        # don't want the pickinglist reprinted when the shipment gets
        # updated.
        if ($handler->iws_rollout_phase >= 1 &&
            $shipment->discard_changes->does_iws_know_about_me &&
            !config_var('PRL', 'rollout_phase')) {
            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::WMS::ShipmentRequest',
                $shipment
            );
        }

        $shipment_notes_delta->report();

        $guard->commit();
        xt_success("Shipment Updated");
    };

    if ( my $err = $@ ) {
        if ( !$redir_form ) {
            xt_warn("An error occurred whilst updating the shipment:<br />${err}");
        }
    }

    return $handler->redirect_to( $redirect );
}

=head2 update_nominated_day($previous_shipping_charge_id, $new_delivery_date_ymd, $shipment, $id_shipment_item, $shipment_address) : 0|1

Update the Shipment Nominated Day columns, nominated_delivery_date,
nominated_dispatch_time, and nominated_earliest_selection_time. If the current
Shipping Charge isn't a Nominated Day one, ensure they aren't set.

If $new_delivery_date_ymd is set, and different from the existing
Delivery Date, update the dates and the SLA time.

=cut

sub update_nominated_day : Export() {
    my ($previous_shipping_charge_id, $new_delivery_date_ymd, $shipment, $id_shipment_item, $shipment_address) = @_;

    my $available_date = should_update_nominated_day(
        $previous_shipping_charge_id,
        $new_delivery_date_ymd,
        $shipment,
        $id_shipment_item,
        $shipment_address,
    );
    if( ! $available_date ) {
        $shipment->reset_nominated_day();
        return 0;
    }

    $shipment->update_nominated_day(
        $available_date->delivery_date,
        $available_date->dispatch_date,
    );


    XT::Data::NominatedDay::Shipment->new()->check_daily_cap(
        $available_date->dispatch_date);

    return 1;
}

# Return an XT::Net::WebsiteAPI::Response::AvailableDate object, or 0,
# or die.
sub ymd {
    my ($datetime) = @_;
    $datetime or return "";
    return $datetime->ymd;
}

# Note: $shipment has already been updated to the new values for
# e.g. shipping_charge_id at this stage
sub should_update_nominated_day {
    my ($previous_shipping_charge_id, $new_delivery_date_ymd, $shipment, $id_shipment_item, $shipment_address) = @_;
    $new_delivery_date_ymd or return 0;

    my $is_date_same = ymd($shipment->nominated_delivery_date) eq $new_delivery_date_ymd;
    my $is_shipping_charge_same = $shipment->shipping_charge_id eq $previous_shipping_charge_id;
    if($is_date_same && $is_shipping_charge_same) {
        return 0;
    }
    $shipment->shipping_charge_table->is_nominated_day or return 0;

    if( is_shipment_selected( $id_shipment_item ) ) {
        die "Can't update the Shipment any longer, it's already selected for picking";
    }

    my $available_date = get_nominated_day_available_date(
        $shipment,
        $new_delivery_date_ymd,
        $shipment_address,
    ) or die("The new Nominated Delivery Date ($new_delivery_date_ymd) is no longer valid\n");

    return $available_date;
}

=head2 is_shipment_selected($id_shipment_item) : 0|1

Return whether the shipment with the Shipment Items in
$id_shipment_item (from Shipment::get_shipment_item_info()).

=cut

sub is_shipment_selected {
    my ($id_shipment_item) = @_;
    return is_shipment_selected_yet(
        get_shipment_stage($id_shipment_item),
    );
}

sub get_nominated_day_available_date {
    my ($shipment, $new_nominated_delivery_date_ymd, $shipment_address) = @_;

    my $nominated_day_available_dates = fetch_available_nominated_delivery_dates_from_website({
        channel  => $shipment->order->channel,
        sku      => $shipment->shipping_charge_table->sku,
        country  => $shipment_address->{country},
        county   => $shipment_address->{county},
        postcode => $shipment_address->{postcode},
    });
    my $available_date =
        first { $new_nominated_delivery_date_ymd eq $_->delivery_date->ymd }
        @$nominated_day_available_dates;

    return $available_date;
}

1;
