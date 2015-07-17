package XTracker::Order::Fulfilment::ViewPEContainer;
use NAP::policy "tt";

use NAP::DC::Barcode::Container;
use XTracker::Handler;
use XTracker::Database::Shipment     qw( :DEFAULT ); # get_shipment_item_info
use XTracker::Database::Distribution qw( get_orphaned_items );

use XTracker::Constants::FromDB qw( :container_status );
use XTracker::Error;
use XTracker::Image; # get_images

my %valid_container_states = map { $_ => 1 } (
    $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS,
    $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS
);

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # Set up the navigation and template
    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Packing Exception';
    $handler->{data}{subsubsection} = 'View Container';
    $handler->{data}{content}
        = 'ordertracker/fulfilment/view_pe_container.tt';

    # Add a 'back' link to the left-side nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} },
        { 'title' => 'Back', 'url' => "/Fulfilment/PackingException" }
    );

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
    my $container = $handler->{schema}->resultset('Public::Container')->find(
        $container_id
    );
    if ( ! $container ) {
        xt_warn("Couldn't find any information on container $container_id");
        return $handler->redirect_to( "/Fulfilment/PackingException" );
    } elsif ( ! $valid_container_states{ $container->status_id } &&
              ! $container->orphan_items->count ) {
        xt_warn("Container $container_id should not be at Packing Exception");
        return $handler->redirect_to( "/Fulfilment/PackingException" );
    } elsif ( ! $valid_container_states{ $container->status_id } &&
              $container->orphan_items->count ) {
        xt_warn("Container $container_id is not in a valid Packing Exception state, and yet still apparently contains unexpected items from a previous packing process. You should fix this and scan the unexpected items out of the container, but it certainly indicates that proper processes have not been followed. After fixing, you might want to consider inventory checks on the affected skus");
    }

    # If there is a shipment associated with the container, then grab info about
    # the shipment items from it
    for my $shipment_id ( $container->shipment_ids ) {
        # Get auxilliary information
        $handler->{data}{shipment_item_info} = {
            # The existing contents of it, if any
            ($handler->{data}{shipment_item_info} ?
                %{ $handler->{data}{shipment_item_info} } : () ),
            # New stuff from this shipment
            %{ get_shipment_item_info( $handler->{dbh}, $shipment_id ) }
        }
    }
    # Add images if we found any items
    if ( $handler->{data}{shipment_item_info} ) {

        foreach my $ship_item_id (
            keys %{ $handler->{data}{shipment_item_info} }
        ) {
            my $product_id = $handler->{data}{shipment_item_info}{$ship_item_id}{product_id};
            $handler->{data}{shipment_item_info}{$ship_item_id}{image} =
                get_images({
                    product_id => $product_id,
                    live => 1,
                    schema => $handler->schema,
                });
            $handler->{data}{shipment_item_info}{$ship_item_id}{product} = $handler->schema->resultset('Public::Product')->find($product_id);
        }
    }

    # Grab out associated orphan items
    $handler->{data}{orphaned_items} = [
        # Just the ones in our tote
        grep { $_->container_id eq $container_id }
        # Retrieve all orphaned items across channels
        map  { @$_ } values %{ get_orphaned_items( $handler->{dbh} ) } ];

    # Get the pretty pictures for them
    foreach my $item ( @{ $handler->{data}{orphaned_items} } ) {
        $handler->{data}->{orphaned_item_images}->{ $item->id } =
            get_images({
                product_id => $item->get_product_id,
                live       => 1,
                schema     => $handler->schema,
            });
    }

    # Save the shipment item ids
    $handler->{data}{shipment_items} = [ $container->shipment_items ];

    $handler->{data}{container} = $container;
    return $handler->process_template;
}

1;
