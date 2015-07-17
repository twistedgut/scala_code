package XTracker::Order::Actions::ChangeShipmentStatus;
use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Order qw( get_order_info );
use XTracker::Database::Shipment qw( set_shipment_on_hold );

use XTracker::EmailFunctions;

use XTracker::Utilities qw( parse_url number_in_list );
use XTracker::Constants::FromDB qw(
    :order_status :shipment_status :shipment_hold_reason
);
use XTracker::Config::Local qw( config_var );
use XTracker::Error;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    # set up vars and get query string data
    my $status_id;
    my $order_id    = $handler->{param_of}{order_id};
    my $shipment_id = $handler->{param_of}{shipment_id};
    my $action      = $handler->{param_of}{action};
    my $incomplete  = $handler->{param_of}{incomplete};
    my $redirect_url   = $short_url.'/OrderView?order_id='.$order_id;

    my $hold_params = {
        operator_id => $handler->{data}{operator_id},
    };
    for my $field (qw(releaseYear releaseMonth releaseDay releaseHour releaseMinute norelease reason comment)) {
        $hold_params->{$field} = $handler->{param_of}{$field};
    };

    eval {

        # we need at least an order id and shipment id
        if ( !$order_id ) {
            die "No order_id defined";
        }
        if ( !$shipment_id ) {
            die "No shipment_id defined";
        }

        # incomplete pick hold via picking screen
        # set hold reason
        # and redirect back there
        if ( $incomplete ) {
            $hold_params->{reason} = $SHIPMENT_HOLD_REASON__INCOMPLETE_PICK;
            $redirect_url   = $short_url.'?redirect=1';
            if ( $handler->{param_of}{view} eq 'HandHeld' ) {
                $redirect_url .= '&view=HandHeld';
            }
        }

        my $schema = $handler->schema;
        my $dbh = $schema->storage->dbh;
        my $guard = $schema->txn_scope_guard;

        my $shipment    = $schema->resultset('Public::Shipment')->find({ id => $shipment_id });

        # hold shipment
        if ( $action eq 'Hold' ) {
            # check if we can hold the shipment
            if( $shipment->shipment_status_id == $SHIPMENT_STATUS__PROCESSING && $shipment->has_packing_started ) {
                die "Sorry, it is too late to hold the shipment as packing has already started.\n";
            } else {
                $status_id = $SHIPMENT_STATUS__HOLD;
            }
        }
        # finance hold shipment
        elsif ( $action eq 'FinanceHold' ) {
            $status_id = $SHIPMENT_STATUS__FINANCE_HOLD;
        }
        # release shipment
        elsif ( $action eq 'Release' ) {

            # get order info from db
            my $order_info              = get_order_info( $dbh, $order_id );
            my  $shipping_restrictions  = $shipment->get_shipping_restrictions_for_pre_order;

            if ( my $ship_on_hold = $shipment->shipment_holds->order_by_id_desc->first ) {
                my $hold_reason = $ship_on_hold->shipment_hold_reason;
                die "Hold '" . $hold_reason->reason . "' can NOT be Manually Released\n"
                        unless ( $hold_reason->manually_releasable );
            }

            if( $shipping_restrictions->{restrict} ) {

                my $msg;
                foreach my $product_id ( keys %{$shipping_restrictions->{restricted_products}//{}} ) {
                    $msg .= $product_id. " : ". join(',' , @{$shipping_restrictions->{restricted_products}->{$product_id}->{reasons}} )."\n" ;
                }
                xt_warn("Cannot release shipment, order contains restricted products which cannot be delivered.\n The Product id(s) and reason are as listed below :\n$msg");

            }
            elsif( number_in_list($order_info->{order_status_id},
                                $ORDER_STATUS__CREDIT_HOLD,
                                $ORDER_STATUS__CREDIT_CHECK ) ) {
                $status_id = $SHIPMENT_STATUS__FINANCE_HOLD;
            }
            else {
                $status_id = $SHIPMENT_STATUS__PROCESSING;
            }
        }

        if ( $status_id ) {

            $hold_params->{status_id} = $status_id;

            # extra steps for hold
            set_shipment_on_hold($handler->schema, $shipment_id, $hold_params)
                if $action eq 'Hold';

            # extra steps for release from hold
            if ( $action eq 'Release' ) {
                $shipment->discard_changes->release_from_hold(
                    operator_id => $hold_params->{operator_id}
                );
                if ( $shipment->is_on_hold ) {
                    xt_warn(q{Attempted to release shipment, but it's back on hold});
                }
                else {
                    xt_success("Shipment Released from Hold");
                }
            }

            if ($shipment->discard_changes->does_iws_know_about_me) {
                $handler->msg_factory->transform_and_send('XT::DC::Messaging::Producer::WMS::ShipmentWMSPause', $shipment );
            }
        }

        $guard->commit();
    };

    if (my $error = $@) {
        xt_warn("An error occured trying to update shipment status:<br />$error" );
    }

    return $handler->redirect_to( $redirect_url );
}

1;
