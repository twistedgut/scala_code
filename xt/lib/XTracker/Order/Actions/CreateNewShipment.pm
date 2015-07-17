package XTracker::Order::Actions::CreateNewShipment;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Config::Local;
use XTracker::Database::Currency;
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Invoice     qw( :DEFAULT create_renum_tenders_for_refund update_card_tender_value );
use XTracker::Database::Product;
use XTracker::Database::Stock qw( :DEFAULT get_saleable_item_quantity );
use XTracker::WebContent::StockManagement;
use XTracker::Utilities qw( parse_url url_encode );
use XTracker::Constants::FromDB qw( :shipment_status :shipment_item_status :shipment_class :pws_action :renumeration_status :renumeration_type :renumeration_class );
use DateTime;
use XTracker::Error;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    # set up vars and get query string data
    my $redirect_url;
    my $order_id            = $handler->{param_of}{order_id};
    my $shipment_id         = $handler->{param_of}{shipment_id};
    my $shipment_class_id   = $handler->{param_of}{shipment_class_id};
    my $extra_charges       = $handler->{param_of}{extra_charges};
    my $total_duties        = 0;
    my $new_shipping_charge = 0;

    if ( $shipment_id && $order_id && $shipment_class_id) {

        eval {
            my $schema  = $handler->schema;
            my $order_rec   = $schema->resultset('Public::Orders')->find( $order_id );

            # get db info for shipment & order
            my $dbh = $schema->storage->dbh;
            my $guard = $schema->txn_scope_guard;

            my $shipment            = get_shipment_info( $dbh, $shipment_id );
            my $order               = get_order_info( $dbh, $order_id );
            my $shipment_items      = get_shipment_item_info( $dbh, $shipment_id );
            my $shipment_address    = get_address_info( $dbh, $shipment->{shipment_address_id} );

            # get a web db handle
            my $stock_manager = XTracker::WebContent::StockManagement->new_stock_manager({
                schema      => $schema,
                channel_id  => $order->{channel_id},
            });


            # calculate new shipping costs
            if ($extra_charges && $shipment->{shipping_charge} > 0){

                my $item_count = 0;

                foreach my $itemid ( keys %{$shipment_items} ){
                    if ($handler->{param_of}{$itemid} eq 'included'){
                        $item_count++;
                    }
                }

                my %shipping_param = (
                        country             => $shipment_address->{country},
                        county              => $shipment_address->{county},
                        postcode            => $shipment_address->{postcode},
                        item_count          => $item_count,
                        order_total         => 1,   # don't worry about order total for now
                        order_currency_id   => $order->{currency_id},
                        shipping_charge_id  => $shipment->{shipping_charge_id},
                        shipping_class_id   => $shipment->{shipping_class_id},
                        channel_id          => $order->{channel_id},
                );

                my $new_shipping = calc_shipping_charges($dbh, \%shipping_param);

                $new_shipping_charge = $new_shipping->{charge};

            }

            # create shipment
            my %new_shipment = (
                date                => DateTime->now(time_zone => 'local')->strftime('%F %R'),
                type_id             => $shipment->{shipment_type_id},
                class_id            => $shipment_class_id,
                status_id           => $SHIPMENT_STATUS__PROCESSING,
                address_id          => $shipment->{shipment_address_id},
                pack_instruction    => $shipment->{packing_instruction},
                shipping_charge     => $new_shipping_charge,
                comment             => '',
                address             => '',
                ( defined $shipment->{av_quality_rating} ?
                    (av_quality_rating  => $shipment->{av_quality_rating}) : () ),
                signature_required  => 1,       # for now set this to be true
                map { $_ => $shipment->{$_} } qw/
                    destination_code
                    email
                    force_manual_booking
                    gift
                    gift_message
                    has_valid_address
                    mobile_telephone
                    shipping_account_id
                    shipping_charge_id
                    telephone
                /
            );


            # if it's not a 'Replacement' then copy the
            # 'signature_required' flag from the Original Shipment
            if ( $shipment_class_id != $SHIPMENT_CLASS__REPLACEMENT ) {
                $new_shipment{signature_required}   = $order_rec->get_standard_class_shipment->signature_required;
            }

            my $new_shipment_id =
                create_reshipment_replacement_shipment(
                    $dbh, $order_id, "order", \%new_shipment);

            log_shipment_status(
                $handler->{dbh},
                $new_shipment_id,
                $SHIPMENT_STATUS__PROCESSING,
                $handler->{data}{operator_id}
            );

            # create shipment items
            my %cancel = ();

            # if a replacement then do final stock level checks
            if ( $shipment_class_id == $SHIPMENT_CLASS__REPLACEMENT ){

                foreach my $itemid ( keys %{$shipment_items} ){
                    if ( $handler->{param_of}{$itemid} eq 'included' ){
                        # item cancelled
                        if ($handler->{param_of}{'cancel-'.$itemid} ){
                            $cancel{$itemid} = 1;
                        }
                        elsif ( $handler->{param_of}{'alt-'.$itemid} ){
                            my $free_stock = get_saleable_item_quantity($dbh, $shipment_items->{$itemid}{product_id} );
                            die "Not enough stock." if $free_stock->{ $order->{sales_channel} }{ $handler->{param_of}{'alt-'.$itemid} } < 1;
                        }
                        else {
                            my $free_stock = get_saleable_item_quantity($dbh, $shipment_items->{$itemid}{product_id} );
                            die "Not enough stock." if $free_stock->{ $order->{sales_channel} }{ $shipment_items->{$itemid}{variant_id} } < 1;
                        }
                    }
                }
            }

            # stock levels okay - create shipment items
            foreach my $itemid ( keys %{$shipment_items} ){
                if ( $handler->{param_of}{$itemid} eq 'included' ){

                    # status to update old shipment item
                    my $old_status_id = $SHIPMENT_ITEM_STATUS__LOST;

                    if ($shipment_class_id == $SHIPMENT_CLASS__RE_DASH_SHIPMENT){
                        $old_status_id = $SHIPMENT_ITEM_STATUS__UNDELIVERED;
                    }

                    update_shipment_item_status($dbh, $itemid, $old_status_id);
                    log_shipment_item_status($dbh, $itemid, $old_status_id, $handler->{data}{operator_id} );

                    if (!$cancel{$itemid}){

                        my $variant_id  = $shipment_items->{$itemid}{variant_id};
                        my $var_field   = 'variant_id';

                        # if it's a Voucher then use Voucher Variant Id
                        if ( $shipment_items->{$itemid}{voucher} ) {
                            $var_field  = 'voucher_variant_id';
                        }

                        # size change processed - get variant id of new size
                        if ( $handler->{param_of}{'alt-'.$itemid} ){
                            $variant_id = $handler->{param_of}{'alt-'.$itemid};
                        }

                        # status of new shipment item
                        # XXX TODO DCEA-773 this is correct! we are re-shipping stuff we got back from the courier, so no need to tell IWS
                        # might need a note to packers "don't use conveyors"
                        my $status_id = $SHIPMENT_ITEM_STATUS__PICKED;

                        if ($shipment_class_id == $SHIPMENT_CLASS__REPLACEMENT){
                            $status_id = $SHIPMENT_ITEM_STATUS__NEW;
                        }

                        my %new_shipment_item = (
                            $var_field     => $variant_id,
                            unit_price     => $shipment_items->{$itemid}{unit_price},
                            tax            => $shipment_items->{$itemid}{tax},
                            duty           => $shipment_items->{$itemid}{duty},
                            status_id      => $status_id,
                            special_order  => 'false',
                            returnable_state_id => $shipment_items->{$itemid}{returnable_state_id},
                            pws_ol_id      => $shipment_items->{$itemid}{pws_ol_id},
                            gift_from      => $shipment_items->{$itemid}{gift_from},
                            gift_to        => $shipment_items->{$itemid}{gift_to},
                            gift_message   => $shipment_items->{$itemid}{gift_message},
                            sale_flag_id   => $shipment_items->{$itemid}{sale_flag_id},
                        );

                        $total_duties += $shipment_items->{$itemid}{duty};

                        my $new_item_id = create_shipment_item($dbh, $new_shipment_id, \%new_shipment_item);

                        # For ShipmentItems linked with reservations
                        my $old_shipment_item_obj = $schema->resultset('Public::ShipmentItem')->find( $itemid );

                        # For New ShipmentItems, link with reservation
                        if( my $link_to_reservation = $old_shipment_item_obj->link_shipment_item__reservations->first ) {
                            my $new_shipment_item_obj   = $schema->resultset('Public::ShipmentItem')->find( $new_item_id );
                            $new_shipment_item_obj->link_with_reservation($link_to_reservation->reservation);
                        }

                        # For new ShipmentItems, link with reservation_by_pid
                        if( my $link_to_reservation_by_pid = $old_shipment_item_obj->link_shipment_item__reservation_by_pids->first ) {
                            my $new_shipment_item_obj   = $schema->resultset('Public::ShipmentItem')->find( $new_item_id );
                            $new_shipment_item_obj->link_with_reservation_by_pid( $link_to_reservation_by_pid->reservation );
                        }

                        # if it's a Voucher copy the Voucher Codes but only for a Re-Shipment
                        if ( $shipment_class_id == $SHIPMENT_CLASS__RE_DASH_SHIPMENT
                          && $shipment_items->{$itemid}{voucher} ) {
                            my $ship_item   = $schema->resultset('Public::ShipmentItem')->find( $new_item_id );
                            # copy the Voucher Code
                            $ship_item->update( { voucher_code_id => $shipment_items->{$itemid}{voucher_code_id} } );
                        }

                        # adjust web stock if a replacement
                        if ($shipment_class_id == $SHIPMENT_CLASS__REPLACEMENT){

                            # adjust website
                            $stock_manager->stock_update(
                                quantity_change => -1,
                                variant_id      => $variant_id,
                                pws_action_id   => $PWS_ACTION__ORDER,
                                operator_id => $handler->{data}{operator_id},
                                notes       => 'Replacement item '.$new_shipment_id,
                            );
                        }
                    }
                }
            }

            # create a refund if any of the items were cancelled
            if ( keys %cancel ){

                my $total_refund    = 0;

                my $inv_id  = create_invoice($dbh, $shipment_id, '', $RENUMERATION_TYPE__CARD_REFUND, $RENUMERATION_CLASS__CANCELLATION, $RENUMERATION_STATUS__AWAITING_ACTION, 0, 0, 0, 0, 0, $order->{currency_id} );

                log_invoice_status( $dbh, $inv_id, $RENUMERATION_STATUS__AWAITING_ACTION, $handler->{data}{operator_id} );

                foreach my $itemid ( keys %{$shipment_items} ){
                    if ( $cancel{$itemid} ){
                        create_invoice_item(
                        $dbh,
                        $inv_id,
                        $itemid,
                        $shipment_items->{$itemid}{unit_price},
                        $shipment_items->{$itemid}{tax},
                        $shipment_items->{$itemid}{duty}
                        );

                        $total_refund   += $shipment_items->{$itemid}{unit_price} +
                                           $shipment_items->{$itemid}{tax} +
                                           $shipment_items->{$itemid}{duty};
                    }
                }

                if ( $total_refund != 0 ) {
                    my $renum   = $schema->resultset('Public::Renumeration')->find( $inv_id );
                    create_renum_tenders_for_refund( $order_rec, $renum, $total_refund );
                }
            }

            # create debit for shipping and duties if selected
            if ( $extra_charges && ($total_duties > 0 || $new_shipping_charge > 0) ){

                my $shipping_charge = 0;

                if ($new_shipping_charge > 0){
                    $shipping_charge = $new_shipping_charge * -1;
                }

                my $inv_id = create_invoice($dbh, $new_shipment_id, '', $RENUMERATION_TYPE__CARD_DEBIT, $RENUMERATION_CLASS__ORDER, $RENUMERATION_STATUS__AWAITING_ACTION, $shipping_charge, 0, 0, 0, 0, $$order{currency_id} );

                log_invoice_status( $dbh, $inv_id, $RENUMERATION_STATUS__AWAITING_ACTION, $handler->{data}{operator_id} );

                foreach my $itemid ( keys %{$shipment_items} ){
                    if ( $handler->{param_of}{$itemid} eq 'included' ){
                        if ( !$cancel{$itemid} && $shipment_items->{$itemid}{duty} > 0 ){
                            create_invoice_item(
                                $dbh,
                                $inv_id,
                                $itemid,
                                0,
                                0,
                                ($shipment_items->{$itemid}{duty} * -1)
                            );
                        }
                    }
                }

                # get invoice total and alter the orders.tender value for Card Debits
                my $total_inv_value = get_invoice_value( $dbh, $inv_id );
                $total_inv_value    = $total_inv_value * -1;
                update_card_tender_value( $order_rec, $total_inv_value );
            }

            $stock_manager->commit;

            # make sure main changes go to database first, so following allocation
            # happens outside main transaction
            $guard->commit();

            # make sure PRL is informed about new allocation
            my $shipment_row = $schema->resultset('Public::Shipment')->find($new_shipment_id)
                or die 'Newly created shipment does not exists in database';

            # Need to rework out the SLA now that we have added all the items etc
            $shipment_row->apply_SLAs();

            $schema->txn_do(sub{
                $shipment_row->allocate({ operator_id => $handler->{data}{operator_id} });
            });

            xt_success('Shipment successfully created.');
            $redirect_url = "$short_url/OrderView?order_id=$order_id";
        };
        if ( my $err = $@ ) {
            xt_die("An error occurred whilst creating the new shipment:<br />$@");
            $redirect_url = "$short_url/CreateShipment?order_id=$order_id&shipment_id=$shipment_id";
        }
    }

    # FIXME: $redirect_url is unset if we don't enter the 'if' block at the top
    # (currently line 36)
    return $handler->redirect_to( $redirect_url );
}

1;
