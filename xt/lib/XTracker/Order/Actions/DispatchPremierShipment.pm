package XTracker::Order::Actions::DispatchPremierShipment;

use strict;
use warnings;
use Try::Tiny;

use XTracker::Database::Order;
use XTracker::Database::Channel         qw( get_channel_details );
use XTracker::Database::Shipment        qw( :DEFAULT :carrier_automation );
use XTracker::Database::Address;

use XTracker::Utilities                 qw( url_encode );
use XTracker::EmailFunctions;
use XTracker::Comms::FCP                qw( update_web_order_status );
use XTracker::Config::Local             qw( contact_telephone dispatch_email shipping_email customercare_email );
use XTracker::Constants::FromDB         qw( :shipment_status :shipment_type :shipment_class :shipment_item_status :correspondence_templates );
use XTracker::Error                     qw( xt_warn xt_success );
use XTracker::Handler;

sub handler {
    my $handler     = XTracker::Handler->new( shift );

    my $error       = '';
    my $response    = '';
    my $redirect    = '/Fulfilment/PremierDispatch';
    my $box_id = $handler->{param_of}{box_id};
    my $shipment_info;
    my $shipment_id;

    my $schema = $handler->schema;
    my $dbh    = $schema->storage->dbh;
    if ($box_id){

        eval {

            my $guard = $schema->txn_scope_guard;
            $shipment_id = get_box_shipment_id( $dbh, $box_id );
            if ($shipment_id) {
                $shipment_info  = get_shipment_info( $dbh, $shipment_id );
            } else {
                die "No shipment found for box id $box_id.\n";
            }

            if ( $shipment_info ) {

                my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);

                if ( $shipment->shipment_type_id != $SHIPMENT_TYPE__PREMIER) {
                    die "This is not a Premier shipment, so cannot be dispatched from this page.\n";
                }
                $shipment->dispatch( $handler->{data}{operator_id} );
            } else {
                die "The shipment for box ID entered ($box_id) could not be found, please check and try again.\n";
            }

            $guard->commit();
        };

        # error in shipment dispatch
        if (my $err = $@) {
            $error = 'An error occurred whilst trying to dispatch this shipment:<br />' . $err;
        } # shipment dispatched - send message
        elsif ( !$error ) {

            $response = 'The shipment was successfully dispatched.';
            try {
                my $row = $schema->resultset('Public::Shipment')
                    ->find($shipment_id);

                if ( $row && $row->order   ) {
                    $handler->msg_factory->transform_and_send(
                                                'XT::DC::Messaging::Producer::Orders::Update',
                                                { order_id       => $row->order->id, }
                                               );
                }

            } catch {
                 $error = $_;
            };
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

