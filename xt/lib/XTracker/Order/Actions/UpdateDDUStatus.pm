package XTracker::Order::Actions::UpdateDDUStatus;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Customer;
use XTracker::Database::Order;
use XTracker::Database::Channel qw( get_channel_details );

use XTracker::EmailFunctions;

use XTracker::Config::Local qw( config_var shipping_email );
use XTracker::Constants::FromDB qw( :shipment_status :flag :correspondence_templates :shipment_hold_reason );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $authorise   = $handler->{request}->param('authorise');

    my $error_msg   = '';
    my $success_msg = '';

    # will hold the Sales Channel of the Shipment
    # so that the correct Channel tab can be shown
    # when Re-Directing back to the listing page
    my $show_channel= '';

    # authorisation decision submitted
    if ( $authorise ) {

        eval {

            my $schema = $handler->schema;
            my $dbh = $schema->storage->dbh;
            my $guard = $schema->txn_scope_guard;
            my $shipment_id = $handler->{request}->param('shipment_id');

            my $shipment_obj= $schema->resultset('Public::Shipment')
                ->find({ id => $shipment_id });

            $show_channel   = '?show_channel=' . $shipment_obj->get_channel->id;

            # remove all ddu flags from shipment
            delete_shipment_ddu_flags($dbh, $shipment_id);

            # terms accepted by customer
            if ( $authorise eq 'authorise_all' ){

                # change shipment status to 'processing' and log it
                update_shipment_status($dbh, $shipment_id, $SHIPMENT_STATUS__PROCESSING, $handler->{data}{operator_id} );

                # set ddh accepted flag
                set_shipment_flag($dbh, $shipment_id, $FLAG__DDU_ACCEPTED);

                $success_msg        = "DDU Charges Accepted for Shipment: ${shipment_id}";
                # customer authorises for all future orders
                set_customer_ddu_authorised($dbh, $handler->{request}->param('customer_id') );
                $success_msg    .= ' and ALL Subsequent Shipments';

                # send email to customer
                if ( $authorise eq 'authorise_all' && $handler->{request}->param('sendemail') eq 'yes'){

                    # get info for email template
                    my $shipment        = get_shipment_info($dbh, $shipment_id);
                    my $address         = get_address_info($dbh, $shipment->{shipment_address_id});
                    my $order           = get_order_info( $dbh, $shipment->{orders_id});
                    my $channel         = get_channel_details( $dbh, $order->{sales_channel});
                    $address->{channel} = $channel;

                    # use a standard placeholder for the Order Number
                    $address->{order_number}    = ( $shipment_obj->order ? $shipment_obj->order->order_nr : '' );
                    my $email_info  = get_and_parse_correspondence_template(
                        $schema,
                        $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__SET_UP_PERMANENT_DDU_TERMS_AND_CONDITIONS,
                        {
                            channel     => $shipment_obj->get_channel,
                            data        => $address,
                            base_rec    => $shipment_obj,
                        }
                    );

                    # send email
                    my $email_sent  = send_customer_email( {
                        to          => $shipment->{email},
                        from        => shipping_email( $channel->{config_section}, {
                            schema  => $schema,
                            locale  => ( $shipment_obj->order ? $shipment_obj->order->customer->locale : '' ),
                        } ),
                        subject     => $email_info->{subject},
                        content     => $email_info->{content},
                        content_type => $email_info->{content_type},
                    } );

                    # log email
                    if ($email_sent == 1){
                        log_shipment_email(
                            $dbh,
                            $shipment_id,
                            $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__SET_UP_PERMANENT_DDU_TERMS_AND_CONDITIONS,
                            $handler->{data}{operator_id}
                        );
                    }

                }
            }
            # terms refused by customer
            elsif ($authorise eq 'no'){

                # set refused flag on shipment
                set_shipment_flag($dbh, $shipment_id, $FLAG__DDU_REFUSED);

                # put shipment on hold ready for cancellation
                update_shipment_status($dbh, $shipment_id, $SHIPMENT_STATUS__HOLD, $handler->{data}{operator_id});

                # create hold record for shipment
                # NOTE: move this into a proper function
                my $qry = "INSERT INTO shipment_hold (shipment_id, shipment_hold_reason_id, operator_id, comment, hold_date) VALUES (?, ?, ?, ?, current_timestamp(0))";
                my $sth = $dbh->prepare($qry);
                $sth->execute( $shipment_id, $SHIPMENT_HOLD_REASON__OTHER, $handler->{data}{operator_id}, 'Refused DDU charges - waiting cancellation.' );

                $success_msg    = "DDU Charges Refused for Shipment: ${shipment_id}";
            }

            if ($shipment_obj->discard_changes->does_iws_know_about_me) {
                $handler->msg_factory->transform_and_send('XT::DC::Messaging::Producer::WMS::ShipmentWMSPause', $shipment_obj );
            }

            $guard->commit();
        };

        if ( my $err = $@ ) {
            $error_msg  = $err;
            $success_msg= '';
        }
    }

    my $redirect = '/Fulfilment/DDU' . $show_channel;

    if ($error_msg) {
        xt_warn($error_msg);
    }

    if ( $success_msg ) {
        xt_success( $success_msg );
    }

    return $handler->redirect_to( $redirect );
}

1;

