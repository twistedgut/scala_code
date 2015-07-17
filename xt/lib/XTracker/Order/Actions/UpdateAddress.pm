package XTracker::Order::Actions::UpdateAddress;

use NAP::policy;
use DateTime::Format::HTTP;

use XTracker::Handler;
use XTracker::Database                  qw( :DEFAULT :common );
use XTracker::Database::Order;
use XTracker::Database::Customer;
use XTracker::Database::Address;
use XTracker::Database::Invoice      qw( :DEFAULT create_renum_tenders_for_refund update_card_tender_value );
use XTracker::Database::OrderPayment qw(check_order_payment_fulfilled);
use XTracker::Database::Shipment     qw( get_shipment_shipping_account set_shipment_shipping_account check_shipment_restrictions get_shipping_charge_data :DEFAULT );
use XTracker::Order::Actions::UpdateShipment qw(
    update_nominated_day
);
use XTracker::EmailFunctions;
use XTracker::Constants::FromDB qw(
    :department
    :flag
    :note_type
    :order_status
    :renumeration_class
    :renumeration_status
    :renumeration_type
    :shipment_status
    :shipment_type
);
use XTracker::Schema::Row::Delta::Shipment;
use XTracker::Error;
use XTracker::Logfile qw/ xt_logger /;
use XTracker::Utilities qw( parse_url );

use XT::Net::Seaview::Client;

use XTracker::Config::Local qw( config_var );

use NAP::Carrier;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    my $operator_id = $handler->operator_id;

    # DB schema
    my $schema  = $handler->schema;
    my $dbh = $handler->dbh;

    my $error_msg = "";

    ### get url and extract section and subsection
    my ($section, $subsection, $short_url) = parse_url($r);

    # Seaview client for central address management
    $handler->{seaview} = XT::Net::Seaview::Client->new({schema => $schema});

    # channel to return back to after updating address
    my $return_channel;

    ### get some form data
    my $address_type = $handler->{param_of}{address_type};

    # FIX FIX FIX FIX FIX
    $handler->{address_type} = $address_type;

    my $shipment_id = $handler->{param_of}{shipment_id};
    my $order_id = $handler->{param_of}{order_id};

    # Address ref we're basing the update on
    $handler->{base_address} = $handler->{param_of}{base_address};

    # use this to pass back to the Edit Address
    # page if the Shipping Address is NOT Valid
    my $can_show_force_address = 0;

    my %addr = (
        first_name      => $handler->{param_of}{first_name},
        last_name       => $handler->{param_of}{last_name},
        address_line_1  => $handler->{param_of}{address_line_1},
        address_line_2  => $handler->{param_of}{address_line_2},
        address_line_3  => $handler->{param_of}{address_line_3},
        towncity        => $handler->{param_of}{towncity},
        county          => $handler->{param_of}{county},
        postcode        => $handler->{param_of}{postcode},
        country         => $handler->{param_of}{country},
    );

    my $order   = $schema->resultset('Public::Orders')->find( $order_id );

    ### hash the new address
    $addr{hash} = hash_address( $dbh, \%addr );

    ### Billing address changed
    if ( $address_type eq "Billing" ) {
        my $order_data = get_order_info( $dbh, $order_id );

        my $address_id = $schema->resultset('Public::OrderAddress')
                                ->matching_id( \%addr );

        if( $address_id == 0 ){
            # Amended address doesn't exist locally - create the local address
            # record and update the order to point to the new address
            try {
                $schema->txn_begin;

                # Add in URN and last modified after the address hashing
                # process so as not to affect the local resource match
                $addr{urn} = $handler->{param_of}{urn};
                $addr{last_modified} = $handler->{param_of}{last_modified};

                $address_id = create_address( $dbh, \%addr );
                update_order_address( $dbh, $order_id, $address_id);
                log_order_address_change( $dbh,
                                          $order_id,
                                          $$order_data{invoice_address_id},
                                          $address_id,
                                          $operator_id);
                link_to_seaview($address_id, \%addr);
                $schema->txn_commit();
            }
            catch {
                $schema->txn_rollback();
                xt_logger->info($_);
                $error_msg = $_;
            };
        }
        elsif( $address_id != 0
                 && $address_id != $$order_data{invoice_address_id}) {
            # Amended address record does exist locally. Update the order to
            # point to the existing address
            try{
                $schema->txn_begin;

                update_order_address( $dbh, $order_id, $address_id);
                log_order_address_change( $dbh,
                                          $order_id,
                                          $$order_data{invoice_address_id},
                                          $address_id,
                                          $operator_id);
                link_to_seaview($address_id, \%addr);
                $schema->txn_commit();
            }
            catch {
                $schema->txn_rollback();
                $error_msg = $_;
            };
        }

        # Seaview: Update remote resource
        my $address_urn
          = seaview_update_or_create($handler, $address_id, $order->customer_id);
    }
    # Shipping address changed
    if ( $address_type eq "Shipping" ) {
        my $new_shipping_charge_id
            = $handler->{param_of}->{selected_shipping_charge_id}
                // xt_die("No selected_shipping_charge_id provided\n");
        my $selected_nominated_delivery_date
            = $handler->{param_of}->{selected_nominated_delivery_date};

        my $shipment = $schema->resultset('Public::Shipment')
            ->find({ id => $shipment_id });

        my $country = $schema->resultset('Public::Country')
            ->find_by_name( $addr{country} );

        # at the end of the eval populate this with the Address Id
        my $address_id_for_seaview;

        # set this if the Billing Address is updated
        # to be the same as the Shipping Address
        my $billing_updated_to_be_the_same_as_shipping = 0;

        # any extra Success Messages that should be shown will be in this variable
        my $xtra_success_msg = '';

        eval {
            $schema->txn_begin;

            # flag used to stop excluding Shipping Department Operators for some Orders
            my $can_ignore_operator_department = 0;

            # some Payment Methods (Klarna) will Cancel the Payment if the
            # PSP rejects the Address Change and the 'Force' option is used
            my $payment_has_been_cancelled_flag = 0;

            # Update signature_required flag
            if($handler->{param_of}{signature_required_flag}) {
                $shipment->update_signature_required(
                    $handler->{param_of}{signature_required_flag},
                    $operator_id
                );
            }

            my $order_data      = get_order_info( $dbh, $order_id );
            my $shipment_data   = get_shipment_info( $dbh, $shipment_id );
            my $shipment_items  = get_shipment_item_info( $dbh, $shipment_id );
            my $current_address = get_address_info( $dbh, $$shipment_data{shipment_address_id} );
            my $address_changed = undef;
            $return_channel = $order_data->{channel_id};

            # Get the restrictions that apply for this shipment going to the
            # new address.

            my $restrictions = check_shipment_restrictions( $handler->{schema}, {
                shipment_id => $shipment_id,
                address_ref => {
                    county       => $addr{county},
                    postcode     => $addr{postcode},
                    country      => $country->country,
                    country_code => $country->code,
                    sub_region   => $country->sub_region->sub_region,
                },
                # don't want to send an email at this stage
                never_send_email => 1,
            } );

            # If there any restrictions, die (throwing the error back to the user).
            die "There are restrictions shipping some products to the new address.\n"
                if ( $restrictions->{restrict} );

            my $shipment_notes_delta = XTracker::Schema::Row::Delta::Shipment->new({
                dbic_row    => $shipment,
                operator_id => $operator_id,
            });

            # address related updates

            # check if new address exists in db
            my $address_id = $schema->resultset('Public::OrderAddress')
                                    ->matching_id( \%addr );

            # if not insert new address
            if ( $address_id == 0 ) {
                # Add in URN and last modified after the address hashing
                # process so as not to affect the local resource match
                $addr{urn} = $handler->{param_of}{urn};
                $addr{last_modified} = $handler->{param_of}{last_modified};

                $address_id = create_address( $dbh, \%addr );
            }

            # update the shipment address if changed
            if ( $address_id != 0 &&  $address_id != $$shipment_data{shipment_address_id}) {
                update_shipment_address( $dbh, $shipment_id, $address_id);
                log_shipment_address_change(
                    $dbh,
                    $shipment_id,
                    $$shipment_data{shipment_address_id},
                    $address_id,
                    $operator_id,
                );
                $address_changed = 1;

                # if required update the Billing Address to be the same as the Shipping Address
                if ( $order && $order->payment_method_insists_billing_and_shipping_address_always_the_same ) {
                    my $orig_address_id = $order->invoice_address_id;
                    update_order_address( $dbh, $order_id, $address_id);
                    log_order_address_change(
                        $dbh,
                        $order_id,
                        $orig_address_id,
                        $address_id,
                        $operator_id
                    );
                    $billing_updated_to_be_the_same_as_shipping = 1;
                }
            }


            # check to see if shipment type, shipping charge or shipping account have changed

            # work out shipping charge for new address
            my $new_shipping_data = get_shipping_charge_data(
                $dbh,
                $new_shipping_charge_id,
            );

            # work out shipment type for new address
            #
            # get info for the new shipping country
            my $new_shipment_type_id = get_country_shipment_type(
                $dbh, $addr{country}, $order_data->{channel_id}
            );
            if (!$new_shipment_type_id) {
                die 'Could not find shipment type for country/channel';
            }

            # check if within Premier Zone
            if ($new_shipping_data->{class} eq "Same Day") {
                $new_shipment_type_id = $SHIPMENT_TYPE__PREMIER;
            }

            # work out shipping account for new address
            #
            my $new_shipping_account_id = get_shipment_shipping_account(
                $dbh,
                {
                    channel_id       => $order_data->{channel_id},
                    shipment_type_id => $new_shipment_type_id,
                    country          => $addr{country},
                    item_data        => $shipment_items,
                    shipping_class   => $new_shipping_data->{class},
                },
            );



            # db updates - if required
            #

            # SHIPMENT_TYPE_ID - new shipment type different to current - update db
            if ($new_shipment_type_id != $shipment_data->{shipment_type_id}) {
                update_shipment_type( $dbh, $shipment_id, $new_shipment_type_id);
            }

            # SHIPPING_CHARGE_ID - new shipping charge id different to current - update db
            if ($new_shipping_charge_id != $shipment_data->{shipping_charge_id}) {
                update_shipment_shipping_charge_id( $dbh, $shipment_id, $new_shipping_charge_id);
            }

            # SHIPPING_ACCOUNT_ID - new shipping account id different to current - update db
            if ($new_shipping_account_id != $shipment_data->{shipping_account_id}) {
                set_shipment_shipping_account( $dbh, $shipment_id, $new_shipping_account_id);
            }

            if ($address_changed) {
                # If the address has changed we need to revalidate it (we will
                # put it on hold later if it hasn't gone on hold for other
                # reasons). Note that this needs to be done *after* we've
                # update the shipping account, or we might pick the wrong
                # carrier.
                $shipment->discard_changes->validate_address({
                    operator_id => $operator_id
                });
                # now notify & validate the Address with the PSP
                # (this will be for Third Party payments only Eg. PayPal)
                if ( !$shipment->discard_changes->validate_address_change_with_psp ) {

                    # get the Payment Method
                    my $payment_method = $order->payments->first
                                                ->payment_method->payment_method;

                    if ( $handler->{param_of}{force_update_address} ) {
                        xt_logger->info(
                            "PSP INVALID ADDRESS FORCED SAVE:" .
                            " Order Nr: " . $order->order_nr .
                            ", Shipment Id: " . $shipment->id .
                            ", Payment Method: ${payment_method}"
                        );

                        my $note_txt =
                            "The Payment Provider '${payment_method}' deemed the Change of Shipping Address" .
                            " Invalid and so a new Payment MUST be taken to Pay for the Order ";

                        if ( !$shipment->should_cancel_payment_after_forced_address_update ) {
                            $note_txt .= "if the new Invalid Address is used.";
                        }
                        else {
                            $note_txt        .= "as the original Payment was Cancelled.";
                            $xtra_success_msg = "The Original Payment has now been Cancelled"
                                               ." and so a new Payment will be Required.";

                            # the Payment now needs to be Cancelled
                            my $cancel_result = $order->discard_changes->cancel_payment_preauth_and_invalidate_payment( {
                                context     => "Edit Shipment Address using Force Update",
                                operator_id => $handler->{data}{operator_id},
                            } ) // {};
                            # if there was a failure (Level 1 failure) to Cancel
                            # then throw an Error as we shouldn't proceed
                            if ( $cancel_result->{error} && $cancel_result->{error} == 1 ) {
                                die "The Payment Provider '${payment_method}' rejected the Address, but the"
                                   ." Payment failed to be Cancelled and so the Change of Address was NOT made."
                                   ." Error message: " . $cancel_result->{message} . "\n";
                            }
                            $payment_has_been_cancelled_flag = 1;
                        }

                        # add the new Address to the end of the note
                        $note_txt .= " New Address: " . $shipment_notes_delta->changes,
                        $order->discard_changes->add_note(
                            $NOTE_TYPE__FINANCE,
                            $note_txt,
                        );

                        # Order should go on Credit Hold even if Shipping
                        # Department Operators have updated the Address
                        $can_ignore_operator_department = 1;
                    }
                    else {
                        xt_logger->info(
                            "PSP INVALID ADDRESS:" .
                            " Order Nr: " . $order->order_nr .
                            ", Shipment Id: " . $shipment->id .
                            ", Payment Method: ${payment_method}"
                        );
                        $can_show_force_address = 1;

                        my $die_msg =
                              "The Payment Provider '${payment_method}' rejected the Address Update because it is Invalid."
                            . " Please try again with a different Address or use the 'Force' option at the end of the process"
                            . " if you believe the Address to be ok.";

                        if ( $shipment->should_cancel_payment_after_forced_address_update ) {
                            $die_msg .= " PLEASE NOTE that the Payment will be Cancelled if the Invalid Address is used"
                                      . " and a NEW Payment will be required to pay for the Order.";
                        }

                        die $die_msg . "\n";
                    }
                }
                else {
                    # this is to get round the fact that Operators in the Shipping Department
                    # never have the Order go on Credit Hold when they change the Shipping
                    # Address, but any Payment Method that needs to notify the PSP should
                    # still attempt to do (if other conditions are met as well)
                    my $payment = $order->payments->first;
                    $can_ignore_operator_department = (
                        # if the Payment's been Fulfilled then
                        # no point in putting it on Credit Hold
                        $payment && !$payment->fulfilled
                        ? $payment->payment_method->notify_psp_of_address_change
                        : 0     # Paid using Store/Voucher Credit then don't care either
                    );
                }
            }


            # take off DDU hold if no longer a DDU shipment
            my $hold_changed = 0;
            my $is_shipment_type_no_longer_ddu = (
                   $shipment_data->{shipment_type_id} == $SHIPMENT_TYPE__INTERNATIONAL_DDU
                && $new_shipment_type_id              != $SHIPMENT_TYPE__INTERNATIONAL_DDU
            );
            if ($is_shipment_type_no_longer_ddu) {
                # currently on hold - change status to "processing"
                if ($shipment_data->{shipment_status_id} == $SHIPMENT_STATUS__DDU_HOLD) {
                    update_shipment_status(
                        $dbh,
                        $shipment_id,
                        $SHIPMENT_STATUS__PROCESSING,
                        $operator_id,
                    );
                    $hold_changed = 1;
                }

                # delete the DDU shipment flags for this shipment
                delete_shipment_ddu_flags($dbh, $shipment_id);
            }


            # put shipment on DDU hold if now DDU
            if ( $new_shipment_type_id == $SHIPMENT_TYPE__INTERNATIONAL_DDU
              && $shipment_data->{shipment_type_id} != $SHIPMENT_TYPE__INTERNATIONAL_DDU
            ) {

                # check if customer has accepted DDU terms before
                if (get_customer_ddu_authorised($dbh, $$order_data{customer_id}) == 0) {
                    if ($$shipment_data{shipment_status_id} == $SHIPMENT_STATUS__PROCESSING || $$shipment_data{shipment_status_id} == $SHIPMENT_STATUS__HOLD) {
                        update_shipment_status(
                            $dbh,
                            $shipment_id,
                            $SHIPMENT_STATUS__DDU_HOLD,
                            $operator_id
                        );
                        $hold_changed = 1;
                    }

                    set_shipment_flag($dbh, $shipment_id, $FLAG__DDU_PENDING);
                }
            }

            # check if order now needs to go back to Credit Hold due to address change
            if (
                    ($address_id != $$shipment_data{shipment_address_id})
                    # Re: DEPARTMENT__SHIPPING: The Shipping
                    # Department is assumed to just fix up address
                    # typos, which means we don't need to re-do any
                    # Credit Checks (CREDIT_HOLD).
                    && ( $handler->department_id != $DEPARTMENT__SHIPPING || $can_ignore_operator_department )
                    && (
                           $$shipment_data{shipment_status_id} == $SHIPMENT_STATUS__PROCESSING
                        || $$shipment_data{shipment_status_id} == $SHIPMENT_STATUS__HOLD
                        || $$shipment_data{shipment_status_id} == $SHIPMENT_STATUS__DDU_HOLD
                    )
                ) {
                update_order_status( $dbh, $order_id, $ORDER_STATUS__CREDIT_HOLD);
                log_order_status( $dbh, $order_id, $ORDER_STATUS__CREDIT_HOLD, $operator_id);

                update_shipment_status($dbh, $shipment_id, $SHIPMENT_STATUS__FINANCE_HOLD, $operator_id);
                $hold_changed = 1;
                set_order_flag($dbh, $order_id, $FLAG__ADDRESS_CHANGE);
            }

            # Put on invalid address hold if we're not already on hold for
            # another reason
            $shipment->discard_changes->hold_if_invalid({
                operator_id => $operator_id
            }) unless $shipment->is_on_hold;


            # check product restrictions on shipment
            if ( $address_id != $$shipment_data{shipment_address_id} ) {
                # do want to send an email at this stage
                check_shipment_restrictions( $schema, { shipment_id => $shipment_id, send_email => 1 } );
            }

            # pricing changes - if required
            if ($handler->{param_of}{new_pricing} && ($handler->{param_of}{new_pricing} == 1)) {

                # collect shipment_item pricing and build up refund data
                my %amend_item = ();
                my %promo_item = ();
                foreach my $item_id ( keys %{ $shipment_items } ) {
                    if ( $handler->{param_of}{'price_'.$item_id} ) {
                        $amend_item{$item_id}{price} = $handler->{param_of}{'price_'.$item_id};
                        $amend_item{$item_id}{tax}   = $handler->{param_of}{'tax_'.$item_id};
                        $amend_item{$item_id}{duty}  = $handler->{param_of}{'duty_'.$item_id};

                        $amend_item{$item_id}{diff_price} = $$shipment_items{$item_id}{unit_price} - $handler->{param_of}{'price_'.$item_id};
                        $amend_item{$item_id}{diff_tax}   = $$shipment_items{$item_id}{tax} - $handler->{param_of}{'tax_'.$item_id};
                        $amend_item{$item_id}{diff_duty}  = $$shipment_items{$item_id}{duty} - $handler->{param_of}{'duty_'.$item_id};
                    }

                    if ( $handler->{param_of}{'promo_'.$item_id} ) {
                        $promo_item{$item_id}{price} = $handler->{param_of}{'promo_price_'.$item_id};
                        $promo_item{$item_id}{tax}   = $handler->{param_of}{'promo_tax_'.$item_id};
                        $promo_item{$item_id}{duty}  = $handler->{param_of}{'promo_duty_'.$item_id};
                    }
                }

                my $amend_shipping = 0;
                my $amend_diff_shipping = 0;
                if ($handler->{param_of}{shipping}) {
                    $amend_shipping = $handler->{param_of}{shipping};
                    $amend_diff_shipping = $$shipment_data{shipping_charge} - $handler->{param_of}{shipping};
                }


                # do database updates

                # update item price
                foreach my $item_id ( keys %amend_item ) {
                    update_shipment_item_pricing(
                        $dbh,
                        $item_id,
                        $amend_item{$item_id}{price},
                        $amend_item{$item_id}{tax},
                        $amend_item{$item_id}{duty},
                    );
                }

                # reset promo values
                foreach my $item_id ( keys %promo_item ) {
                    reset_shipment_item_promotion(
                        $dbh,
                        {
                            shipment_item_id => $item_id,
                            unit_price       => $promo_item{$item_id}{price},
                            tax              => $promo_item{$item_id}{tax},
                            duty             => $promo_item{$item_id}{duty}
                        }
                    );
                }

                # update shipping charge
                if ($amend_shipping) {
                    update_shipment_shipping_charge($dbh, $shipment_id, $amend_shipping);
                }


                # Datacash Payment has been fulfilled - create new payment
                if (check_order_payment_fulfilled($dbh, $order_id)) {

                    ### create refund/debit
                    if ( ( $handler->{param_of}{refund_type} // 0 ) > 0) {
                        my $refund_type = $handler->{param_of}{refund_type};
                        my $diff_total  = $amend_diff_shipping;

                        my $inv_id = create_invoice(
                            $dbh, $shipment_id,
                            '',
                            $handler->{param_of}{refund_type},
                            $RENUMERATION_CLASS__ORDER,
                            $RENUMERATION_STATUS__AWAITING_ACTION,
                            $amend_diff_shipping, 0, 0, 0, 0, $$order_data{currency_id}
                        );

                        log_invoice_status(
                            $dbh,
                            $inv_id,
                            $RENUMERATION_STATUS__AWAITING_ACTION,
                            $operator_id,
                        );

                        foreach my $item_id ( keys %amend_item ) {
                            create_invoice_item(
                                $dbh,
                                $inv_id,
                                $item_id,
                                $amend_item{$item_id}{diff_price},
                                $amend_item{$item_id}{diff_tax},
                                $amend_item{$item_id}{diff_duty}
                            );

                            $diff_total +=
                                $amend_item{$item_id}{diff_price} +
                                $amend_item{$item_id}{diff_tax} +
                                $amend_item{$item_id}{diff_duty};
                        }

                        if ( $refund_type != $RENUMERATION_TYPE__CARD_DEBIT && $diff_total != 0 ) {
                            my $renum = $schema->resultset('Public::Renumeration')->find( $inv_id );
                            create_renum_tenders_for_refund( $order, $renum, $diff_total );
                        }

                        # at this stage we will only increase the orders.tender value
                        # for Card Debits not decrease which is safer for making returns
                        if ( $refund_type == $RENUMERATION_TYPE__CARD_DEBIT ) {
                            my $total_inv_value = get_invoice_value( $dbh, $inv_id );
                            $total_inv_value    = $total_inv_value * -1;
                            update_card_tender_value( $order, $total_inv_value );
                        }
                    }
                    else {
                        # update orders.tender value for card debit even if difference is between 0 and 3
                        my $diff_total  = $amend_diff_shipping;
                        foreach my $item_id ( keys %amend_item ) {
                            $diff_total +=
                                $amend_item{$item_id}{diff_price} +
                                $amend_item{$item_id}{diff_tax} +
                                $amend_item{$item_id}{diff_duty};
                        }
                        $diff_total = $diff_total * -1;
                        if ( $diff_total > 0 ) {
                            # at this stage we will only increase the orders.tender value
                            # for Card Debits not decrease which is safer for making returns
                            update_card_tender_value( $order, $diff_total );
                        }
                    }
                }
                # Datacash Payment has NOT been fulfilled - invalidate pre-auth
                else {
                    # loop through differences
                    my $diff_total  = $amend_diff_shipping;
                    foreach my $item_id ( keys %amend_item ) {
                        $diff_total +=
                            $amend_item{$item_id}{diff_price} +
                            $amend_item{$item_id}{diff_tax} +
                            $amend_item{$item_id}{diff_duty};
                    }
                    if ( $diff_total != 0 ) {
                        $diff_total *= -1; # flip, so that it's appropriate to increase/decrease the tender value
                        update_card_tender_value( $order, $diff_total );
                    }

                    # only tell the PSP about any changes if the Payment hasn't been Cancelled
                    if ( !$payment_has_been_cancelled_flag ) {
                        my $result = $shipment->discard_changes->notify_psp_of_basket_changes_or_cancel_payment( {
                            context     => "Edit Shipment Address",
                            operator_id => $handler->{data}{operator_id},
                        } );
                        if ( $result->{payment_deleted} ) {
                            my $replaced_payment = $order->discard_changes->replaced_payments->order_by_id_desc->first;
                            $xtra_success_msg = "'" . $replaced_payment->payment_method_name . "' payment has been removed " .
                                                "because it is no longer needed to pay for the Order";
                        }
                        else {
                            # put the order in invalid queue if beyond threshold
                            $order->invalidate_order_payment;
                        }
                    }
                }
            }


            my $new_shipment_address = get_address_info($dbh, $address_id);
            my $new_shipment_items   = get_shipment_item_info($dbh, $shipment_id);
            $shipment->discard_changes;
            update_nominated_day(
                $shipment_data->{shipping_charge_id}, # previous shipping_charge_id
                $selected_nominated_delivery_date,    # new delivery date
                $shipment,
                $new_shipment_items,
                $new_shipment_address,
            );

            # only after phase 0, since in phase 0 it would print out a
            # new pick-sheet and confuse people
            if (        $shipment->does_iws_know_about_me
                     && $handler->iws_rollout_phase > 0
                     && !config_var('PRL', 'rollout_phase')
                 ) {
                $handler->msg_factory->transform_and_send('XT::DC::Messaging::Producer::WMS::ShipmentRequest', $shipment );
                if ($hold_changed) {
                    $handler->msg_factory->transform_and_send(
                        'XT::DC::Messaging::Producer::WMS::ShipmentWMSPause',
                        $shipment,
                    );
                }
            }

            $shipment_notes_delta->report();

            $address_id_for_seaview = $address_id;

            $schema->txn_commit();
        };
        if ( my $error = $@ ) {
            xt_logger->warn( "Error Updating Shipping Address for Shipment '${shipment_id}': ${error}" );
            $error_msg = $error;
            $schema->txn_rollback();
        }
        else {
            xt_success( "Shipment Address has been Updated." );
            xt_success( "Billing Address has also been Updated to be the same because of this Order's Payment Method." )
                            if ( $billing_updated_to_be_the_same_as_shipping );
            xt_success( $xtra_success_msg )     if ( $xtra_success_msg );

            ### send customer email - if selected
            if ($handler->{param_of}{send_email} && ($handler->{param_of}{send_email} eq "yes")){

                my $email_sent = send_customer_email( {
                    to           => $handler->{param_of}{email_to},
                    from         => $handler->{param_of}{email_from},
                    reply_to     => $handler->{param_of}{email_replyto},
                    subject      => $handler->{param_of}{email_subject},
                    content      => $handler->{param_of}{email_body},
                    content_type => $handler->{param_of}{email_content_type},
                } );

                if ($email_sent == 1){
                    $schema->txn_begin;
                    log_shipment_email($dbh, $shipment_id, 30, $operator_id);
                    $schema->txn_commit();
                }

            }

            # don't need to bother the Operator
            # if this fails, just log any issues
            eval {
                # Seaview: Update remote resource
                my $address_urn
                  = seaview_update_or_create($handler, $address_id_for_seaview, $order->customer_id);
            };
            if ( my $error = $@ ) {
                xt_logger->warn( "Error Updating Seaview for Shipment '${shipment_id}': ${error}" );
            }
        }
    }

    my $redirect;
    # if we've got an error then redirect back to Edit Address page
    if ($error_msg){
        xt_logger->error($error_msg);
        xt_warn($error_msg);
        if ( $address_type eq "Shipping" ) {
            $redirect  = "$short_url/EditAddress?address_type=Shipping&order_id=$order_id&shipment_id=$shipment_id";
            $redirect .= '&can_show_force_address=' . $can_show_force_address;
        }
        else {
            $redirect= "$short_url/EditAddress?address_type=Billing&order_id=$order_id";
        }
    }
    # everything okay - then redirect back to Order View or Invalid/Manual Shipments page
    else {
        if ( $subsection =~ /^(Invalid\s?Shipments|Invalid\s?Address\s?Shipments)$/ ) {
            $redirect= $short_url . ( $return_channel ? "?show_channel=$return_channel" : "" );
        }
        else {
            $redirect= "$short_url/OrderView?order_id=$order_id";
        }
    }

    return $handler->redirect_to($redirect);
}

=head1 METHODS

=head2 seaview_create_address

=cut

sub seaview_create_address {
    my ($handler, $customer_id, $local_address) = @_;

    my $address_urn   = undef;
    my $addr_data_obj = $local_address->as_data_obj;

    try{
        if(my $account_urn
             = $handler->{seaview}->registered_account($customer_id)){

            my $tx_ref = sub {
                # Add account ref to XT::Data::Address
                $addr_data_obj->{account_urn} = $account_urn;
                $addr_data_obj->{address_type} = $handler->{address_type};

                # Add the address to Seaview
                $address_urn
                  = $handler->{seaview}->add_address($addr_data_obj);

                $local_address->urn($address_urn);
                $local_address->last_modified(
                    $handler->{seaview}->address($address_urn)->last_modified);
                $local_address->update;
            };

            # The extra commit is necessary - see XTracker::Handler for
            # details
            $handler->schema->txn_do($tx_ref);
        }
    }
    catch {
        if ($_ ~~ match_instance_of('XT::Net::Seaview::Exception::NetworkError')) {
            # Seaview service is down
            xt_logger->warn($_);
            my $user_msg = 'Seaview service is not currently available'
                . ' - the order address has been updated locally'
                . ' but has not been created in Seaview';
            xt_warn($user_msg);
        }
        else {
            # Something else has happened. Who can say what?
            xt_logger->warn($_);
        }
    };

    return $address_urn;
}

=head2 seaview_update_address

Update Seaview address

=cut

sub seaview_update_address {
    my ($handler, $local_address) = @_;

    # Create a data object from the local schema
    my $addr_data_obj = $local_address->as_data_obj;

    my $address_urn = undef;
    try{
        # Transfer the address update to Seaview
        $address_urn = $handler->{seaview}->update_address($addr_data_obj->urn,
                                                           $addr_data_obj);

        # Grab the last-modified date/time
        my $headers
          = $handler->{seaview}->address_meta($addr_data_obj->urn);

        my $tx_ref = sub {
            # Add the latest Last-Modified value from the service resource and
            # make sure we have a URN reference
            $local_address->last_modified(
              DateTime::Format::HTTP->parse_datetime(
                $headers->header('Last-Modified')));
            $local_address->update;
        };

        # If the local update fails we can just carry on. The next time we
        # update the remote update will fail, however
        # The extra commit is necessary - see XTracker::Handler for details
        $handler->schema->txn_do($tx_ref);
    }
    catch {
        if ($_ ~~ match_instance_of('XT::Net::Seaview::Exception::ClientError')) {
            if ( $_->code == 412 ) {
                # Precondition failed - the request has been rejected
                # Roll back database update
                xt_logger->warn($_);
                my $user_msg = 'The Seaview address has been updated by the customer'
                    . ' since making this order and therefore this update '
                    . ' cannot be applied to the customer\'s web site'
                    . ' accounts. The address change has been applied'
                    . ' for this order only';
                xt_warn($user_msg);
            }
            elsif ( $_->code == 404 ){
                # Address no longer exists in Seaview
                xt_logger->warn($_);
                my $user_msg = "Address no longer exists in Seaview.\n"
                    . ' The order address change for this order'
                    . ' has been applied but the address has not'
                    . ' been updated in Seaview';
                xt_warn($user_msg);
            }
            else {
                # Something else has happened. Just log it and carry on.
                xt_logger->warn($_);
            }
        }
        else {
            # Something else has happened. Just log it and carry on.
            xt_logger->warn($_);
        }
    };

    return $address_urn;
}

=head2 seaview_break_address_link

=cut

sub seaview_break_address_link {
    my ($handler, $local_address) = @_;

    try{
        my $tx_ref = sub {
            $local_address->urn(undef);
            $local_address->last_modified(undef);
            $local_address->update
        };

        # The extra commit is necessary - see XTracker::Handler for details
        $handler->schema->txn_do($tx_ref);
    }
    catch {
        # We can just let this operation fail and log it. The Last-Modified
        # will be out of date so further Seaview updates will fail anyway
        xt_logger->info($_);
    };

    xt_logger->info('Local address detached from Seaview');

    return 1;
}


sub seaview_update_or_create {
    my ($handler, $address_id, $customer_id) = @_;

    my $address_urn = undef;

    # Find the local address that the order now points to
    my $local_address = $handler->schema
                                ->resultset('Public::OrderAddress')
                                ->find($address_id);

    # Are we basing the update on a Seaview resource?
    if(defined $handler->{base_address}
         && $handler->{seaview}->service->seaview_resource($handler->{base_address})){
        unless($address_urn
                 = seaview_update_address($handler, $local_address)){
            seaview_break_address_link($handler, $local_address);
        }
    }
    else{
        # We don't have a URN to work from. Update the local address
        # as required. Create the Seaview address and add URN and
        # last-modified to local record
        $address_urn = seaview_create_address($handler,
                                              $customer_id,
                                              $local_address);
    }

    return $address_urn;
}

sub link_to_seaview {
    my ($handler, $address_id, $addr_params) = @_;

    if(defined $addr_params->{urn}
         && defined $addr_params->{last_modified}){

        my $local_address = $handler->schema
                                    ->resultset('Public::OrderAddress')
                                    ->find($address_id);

        $local_address->urn($addr_params->{urn});
        $local_address->urn($addr_params->{last_modified});
        $local_address->update;
    }

    return 1;
}

1;
