package XTracker::Order::Fulfilment::SendCancelledToPutaway;
use NAP::policy "tt";

use NAP::DC::Barcode::Container;

use XTracker::Handler;
use XTracker::Constants::FromDB qw( :container_status :pws_action );
use XTracker::Database qw/get_database_handle/;
use XTracker::Error;
use XTracker::Config::Local qw(
    putaway_intransit_type
);
use NAP::DC::Barcode::Container::Tote;
use XT::Data::Fulfilment::Putaway;

my %valid_container_states = map { $_ => 1 } (
    $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS,
);

sub handler {
    my $r       = shift;
    my $handler = XTracker::Handler->new($r);
    my $schema = $handler->{schema};

    # Get the incoming Container ID, and reject it for all sorts of reasons...
    my $container_id = $handler->{param_of}{container_id};
    if ( ! $container_id ) {
        xt_warn("You must provide a container id to view a container");
        return $handler->redirect_to( "/Fulfilment/PackingException" );
    }
    my $err;
    try {
        $container_id = NAP::DC::Barcode::Container->new_from_id(
            $container_id,
        );
        $err = 0;
    }
    catch {
        xt_warn($_);
        $err = 1;
    };
    return $handler->redirect_to( "/Fulfilment/PackingException" ) if $err;

    # Check that we can find that container, and it's in the right state
    my $container = $schema->resultset('Public::Container')->find(
        $container_id
    );
    if ( ! $container ) {
        xt_warn("Couldn't find any information on container $container_id");
        return $handler->redirect_to( "/Fulfilment/PackingException" );
    } elsif ( ! $valid_container_states{ $container->status_id } ) {
        xt_warn("$container_id is not a container of unexpected and cancelled items");
        return $handler->redirect_to( "/Fulfilment/PackingException" );
    }

    # Check that container has no orphaned items in it
    if ( $container->orphan_items->count ) {
        xt_warn("Container $container_id still has orphaned items in it");
        return $handler->redirect_to(
            "/Fulfilment/PackingException/ViewContainer?container_id=$container_id"
        );
    }

    # * Remove the items from it

    # Find shipment items
    my $putaway = XT::Data::Fulfilment::Putaway->new_by_type();
    my $operator_row = $schema->find( Operator => $handler->operator_id );
    for my $shipment_item_row ( $container->shipment_items ) {
        $container->remove_item({ shipment_item => $shipment_item_row });

        $putaway->send_cancelled_shipment_item_to_putaway(
            $shipment_item_row,
            $operator_row,
        );
    }

    # If it was a tote, get busy, otherwise INVAR is already on the case
    try {
        NAP::DC::Barcode::Container::Tote->new_from_id($container->id);
        xt_info( $putaway->marked_for_putaway_user_message($container_id) );
    }
    catch {
        xt_success("Container marked for putaway");
    };

    return $handler->redirect_to( "/Fulfilment/PackingException" );
}

1;
