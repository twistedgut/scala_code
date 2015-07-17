package XTracker::Order::Fulfilment::PackingExceptionCancelPendingMultiplexer;

use strict;
use warnings;

use Digest::MD5 qw/md5_hex/;
use XTracker::Handler;
use XTracker::Constants::FromDB  qw( :shipment_item_status );
use URI;
use URI::QueryParam;
use XTracker::Error;

use XTracker::DBEncode              qw( encode_it );

use Plack::App::FakeApache1::Constants qw(:common);
# use XTracker::Image;
# use XTracker::Database qw( get_schema_using_dbh get_database_handle);
# use XTracker::Database::Shipment        qw( :DEFAULT :carrier_automation );
# use XTracker::Database::Address;
# use XTracker::Database::Product;
# use XTracker::Database::StockTransfer   qw( get_stock_transfer );
# use XTracker::Database::Order;
#
# use XTracker::Utilities                 qw( parse_url get_transaction_code url_encode number_in_list );
# use XTracker::Constants::FromDB         qw(
#     :note_type :shipment_type :shipment_item_status :shipment_status
#     :container_status
# );
# use XTracker::Navigation                qw( build_packing_nav );
#


### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {
    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    # Validate incoming data. We're going to sanity-check this rather than
    # properly check this as it's not user-entered - we'll just check that the
    # incoming data won't break anything, rather than hand-hold the user...

    # Find the shipment
    my $shipment = $handler->{schema}->resultset('Public::Shipment')->find(
        $handler->{param_of}{shipment_id} || ''
    ) || do {
        xt_warn("Can't find that shipment");
        return $handler->redirect_to( '/Fulfilment/PackingException' );
    };

    # Check it hasn't changed
    unless ( md5_hex( encode_it( $shipment->state_signature) ) eq $handler->{param_of}{shipment_state_signature} ) {
        warn "New hash:" . md5_hex( encode_it( $shipment->state_signature) );
        warn "Old hash:" . $handler->{param_of}{shipment_state_signature};
        xt_warn(sprintf("Shipment %s has changed since you started working on it. Your last action has been ignored. Carry on.",$shipment->id));
        return $handler->redirect_to( '/Fulfilment/Packing/CheckShipmentException?shipment_id=' . $shipment->id );
    }

    # Get the shipment item
    my ($shipment_item) = $handler->{schema}->resultset('Public::ShipmentItem')->search({
        id                      => $handler->{param_of}{shipment_item_id},
        shipment_id             => $shipment->id,
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
    });
    unless ( $shipment_item ) {
        xt_warn("Can't find shipment item " . $handler->{param_of}{shipment_item_id} );
        return $handler->redirect_to( '/Fulfilment/PackingException' );
    }

    # Prep redirection URI for where it's needed
    my $uri = URI->new('/Fulfilment/PackingException/ScanOutPEItem');
    $uri->query_param( shipment_id => $shipment->id           );
    $uri->query_param( shipment_item_id => $shipment_item->id );
    # Both used as different forms use different things
    $uri->query_param( state_signature  => md5_hex( encode_it($shipment->state_signature) ) );
    $uri->query_param( shipment_state_signature => md5_hex( encode_it($shipment->state_signature) ) );

    # Putaway
    if ( $handler->{param_of}{putaway} ) {

        $uri->query_param( clear_fail => 1 );
        $uri->query_param( putaway    => 1 );
        $uri->query_param( situation  => 'removeCancelPending' );
        return $handler->redirect_to( $uri );

    # Quarantine
    } elsif ( $handler->{param_of}{quarantine} ) {

        $uri->query_param( faulty    => 1 );
        $uri->query_param( situation => 'removeFaulty' );
        return $handler->redirect_to( $uri );

    # Missing
    } elsif ( $handler->{param_of}{missing} ) {

        $uri->path('/Fulfilment/Packing/CheckShipmentException');
        $uri->query_param( missing   => 1 );
        return $handler->redirect_to( $uri );

    }

}

1;
