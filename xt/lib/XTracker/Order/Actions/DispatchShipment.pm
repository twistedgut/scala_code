package XTracker::Order::Actions::DispatchShipment;

use strict;
use warnings;
use Try::Tiny;

use XTracker::Database                  qw( get_database_handle
    get_schema_using_dbh);
use XTracker::Database::Order;
use XTracker::Database::Channel         qw( get_channel_details );
use XTracker::Database::Shipment        qw( :DEFAULT :carrier_automation );
use XTracker::Database::Address;

use XTracker::Utilities                 qw( url_encode );
use XTracker::EmailFunctions            qw( get_and_parse_correspondence_template send_customer_email );
use XTracker::Comms::FCP                qw( update_web_order_status );
use XTracker::Config::Local             qw( contact_telephone dispatch_email shipping_email customercare_email );
use XTracker::Constants::FromDB         qw( :shipment_status :shipment_type :shipment_class :shipment_item_status :correspondence_templates );
use XTracker::Error                     qw( xt_warn xt_success );
use XTracker::Handler;

sub handler {
    my $handler     = XTracker::Handler->new( shift );

    my $error       = '';
    my $response    = '';
    my $redirect    = '/Fulfilment/Dispatch';
    my $shipment_id = $handler->{param_of}{shipment_id};
    my $shipment_info;

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;
    if ($shipment_id){

        eval {

            my $guard = $schema->txn_scope_guard;
            # if the length of the shipment id is >= 10
            # then assume it's an Outward AWB and translate
            # it into a shipment id
            if ( length( $shipment_id ) >= 10 ) {
                $shipment_id    = get_shipment_id_for_awb( $dbh, { outward => $shipment_id, not_yet_dispatched => 1 } );
            }

            $shipment_info  = get_shipment_info( $dbh, $shipment_id );

            my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);

            if ( $shipment && $shipment_info ) {

                # airway bill numbers required and not present
                if ( !$shipment->has_correct_proforma ) {
                    die "The shipment does not have AWBs assigned\n";
                }

                $shipment->dispatch( $handler->{data}{operator_id} );
            }
            else {
                # give different error message if AWB was supplied
                if ( length( $handler->{param_of}{shipment_id} ) >= 10 ) {
                    die 'Could not find an Un-Dispatched Shipment for Outward AWB: '
                           . $handler->{param_of}{shipment_id} . "\n";
                }
                else {
                    die "The shipment number entered ($shipment_id) could not be found, please check and try again.\n";
                }
            }

            $guard->commit;
        };

        # error in shipment dispatch
        if (my $err = $@) {
            $error = 'An error occurred whilst trying to dispatch this shipment:<br />' . $err;
        }

        # shipment dispatched - send customer email confirmation
        elsif ( $error eq '' ) {

            $response = 'The shipment was successfully dispatched.';

            # customer email
            my $email_data;

            eval {

                # send dispatch email for non-premier orders
                if ( $shipment_info->{shipment_type_id} != $SHIPMENT_TYPE__PREMIER ) {
                    my $guard = $schema->txn_scope_guard;

                    $email_data->{shipment}          = $shipment_info;
                    $email_data->{shipment_boxes}    = get_shipment_boxes( $dbh, $shipment_id );
                    $email_data->{order_id}          = get_shipment_order_id( $dbh, $shipment_id );
                    $email_data->{order}             = get_order_info( $dbh, $email_data->{order_id});
                    $email_data->{channel}           = get_channel_details( $dbh, $email_data->{order}{sales_channel});
                    $email_data->{invoice_address}   = get_address_info( $dbh, $email_data->{order}{invoice_address_id});
                    $email_data->{contact_telephone} = contact_telephone( $email_data->{channel}{config_section} );

                    $email_data->{shipment_row}      = $schema->resultset('Public::Shipment')->find( $shipment_id );

                    # get the Customer's Locale so the correct Email Addresses can be used
                    my $customer_locale = (
                                            $email_data->{shipment_row}->order
                                            ? $email_data->{shipment_row}->order->customer->locale
                                            : ''
                                        );
                    my $dispatch_email  = dispatch_email( $email_data->{channel}{config_section}, {
                        schema  => $schema,
                        locale  => $customer_locale,
                    } );
                    my $shipping_email  = shipping_email( $email_data->{channel}{config_section}, {
                        schema  => $schema,
                        locale  => $customer_locale,
                    } );
                    $email_data->{customercare_email}   = customercare_email( $email_data->{channel}{config_section}, {
                        schema  => $schema,
                        locale  => $customer_locale,
                    } );

                    # use a standard placeholder for the Order Number
                    $email_data->{order_number} = $email_data->{order}{order_nr};
                    my $email_info      = get_and_parse_correspondence_template( $schema, $CORRESPONDENCE_TEMPLATES__DISPATCH_ORDER, {
                                                                                    channel => $email_data->{shipment_row}->get_channel,
                                                                                    data    => $email_data,
                                                                                    base_rec=> $email_data->{shipment_row},
                                                                            } );

                    my $email_sent = send_customer_email( {
                                                to          => $email_data->{order}{email},
                                                from        => $dispatch_email,
                                                reply_to    => $shipping_email,
                                                subject     => $email_info->{subject},
                                                content     => $email_info->{content},
                                                content_type=> $email_info->{content_type},
                                            } );

                    if ($email_sent == 1){
                        $email_data->{shipment_row}->log_correspondence( $CORRESPONDENCE_TEMPLATES__DISPATCH_ORDER, $handler->{data}{operator_id} );
                    }
                    $guard->commit();
                }

                # send a status update over AMQ

                try {
                    my $row = $schema->resultset('Public::Shipment')
                        ->find($shipment_id);

                    my $order = $row->order;
                    if ( $order ) {
                        $handler->msg_factory->transform_and_send(
                                                    'XT::DC::Messaging::Producer::Orders::Update',
                                                    { order_id       => $order->id, }
                                                   );
                    }

                } catch {
                    xt_warn( $_ );
                };
            };
            if ( my $err = $@ ) {
                xt_warn( "Order Dispatched but an Error occured trying to Email the Customer: " . $err );
            }

            # This code doesn't take into account sample shipments, which
            # appear to not populate $email_data. Everything except finding the
            # channel was being skipped anyway, as $email_data conditions
            # surround the rest, so I'm silencing the DBIC undef find warning.
            if ( $email_data->{channel}{id} ) {
                my $channel = $schema->resultset('Public::Channel')->find( $email_data->{channel}{id} );
                # we are sending via AMQ and updating using db handle for now
                # later we will need to take out the db update once we're happy
                # the AMQ stuff works hunkydory

                # Website order status update to dispatched
                if ($email_data->{order}{order_nr}
                    && $email_data->{channel}{config_section}
                    && !$channel->is_fulfilment_only) {
                    eval {
                        my $dbh_web = get_database_handle( { name => 'Web_Live_'.$email_data->{channel}{config_section}, type => 'transaction' } );
                        update_web_order_status($dbh_web, { 'orders_id' => $email_data->{order}{order_nr}, 'order_status' => "DISPATCHED" } );
                        $dbh_web->commit();
                    };
                }
            }
        }
    }

    if ($error) {
        if ($handler->{data}{handheld}) {
            $error = 'DO NOT DISPATCH!<br /><br />'
                   . $error;
        }
        xt_warn($error);
    }
    elsif ($response) {
        xt_success($response);
    }
    if ( $handler->{data}{handheld} ) {
        $redirect   .= '?view=HandHeld';
    }

    return $handler->redirect_to( $redirect );
}

1;

