package XT::DC::Controller::PreOrder::BulkRelease::UpdateOrderStatus;
use Moose;

BEGIN { extends 'NAP::Catalyst::Controller::REST' };

=head1 NAME

XT::DC::Controller::PreOrder::BulkRelease::UpdateOrderStatus

=head2 DESCRIPTION

REST Controller for the following URLs:

    /API/StockControl/Reservation/PreOrder/PreOrderOnhold/UpdateOrderStatus

=cut

use XTracker::Constants::FromDB qw( :shipment_status );
use XTracker::Database::Utilities;
use XTracker::Logfile qw( xt_logger );

use Try::Tiny;

=head2 update_order_status

URL: /API/StockControl/Reservation/PreOrder/PreOrderOnhold/UpdateOrderStatus

Updates a given orders status. Only accepts a POST request with the following payload:

{ order_id: <order id> }

=cut

sub update_order_status :
    Path('/API/StockControl/Reservation/PreOrder/PreOrderOnhold/UpdateOrderStatus')
    ActionClass('REST') {}

sub update_order_status_POST {
    my ( $self, $c ) = @_;

    if ( $c->check_access( 'Stock Control', 'Reservation' ) ) {

        try {

            my $data = $c->request->data;

            return $self->status_bad_request( $c, message => 'Missing order ID' )
                unless exists $data->{order_id};

            return $self->status_bad_request( $c, message => 'Invalid order ID' )
                unless is_valid_database_id( $data->{order_id} );

            my $order_id    = $data->{order_id};
            my $order       = $c->model('DB::Public::Orders')->find( $order_id );

            if ( $order ) {

                return $self->status_bad_request( $c,
                    message => 'Order ' . $order->order_nr . ' is not on Pre-Order hold and cannot be released' )
                        unless $order->get_standard_class_shipment->is_on_hold_for_pre_order_hold_reason;

                $order->get_standard_class_shipment->set_status_processing(
                    $c->session->{operator_id} );

                return $self->status_ok( $c, entity => {
                    status => 'SUCCESS',
                } );

            } else {

                return $self->status_bad_request( $c,
                    message => "Order ID $order_id does not exist" );

            }

        } catch {

            xt_logger->error( "Failed to update order status: $_" );

            # Gave up trying to respond with an internal server error, as XT
            # "helpfully" replaces the JSON with a nice friendly HTML error page!
            return $self->status_bad_request( $c,
                message => 'There was a problem processing the request' );

        };

    } else {

        $self->status_unauthorized( $c );
        $c->detach;

    }

}

1;
