package XTracker::Order::Fulfilment::RemoveOrphanFromContainer;
use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Database::Distribution qw( get_orphaned_items );
use XTracker::Constants::FromDB qw( :container_status );
use XTracker::Error;

my %valid_container_states = map { $_ => 1 } (
    $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS,
    $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS
);

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # Get the incoming Container ID, and reject it for all sorts of reasons...
    my $container_id = $handler->{param_of}{container_id};
    if ( ! $container_id ) {
        xt_warn("You must provide a container id to view a container");
        return $handler->redirect_to( "/Fulfilment/PackingException" );
    }
    my $err;
    try {
        $container_id = NAP::DC::Barcode::Container->new_from_id(
            $container_id, # Rendered id, not scanned into a form
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
    }

# Deal with incoming product

    # Get the incoming SKU, and reject it for all sorts of reasons...
    my $sku = $handler->{param_of}{sku};
    $sku =~ s/\s//g;

    # Check it's sane
    if ( ! $sku ) {
        xt_warn("You must provide a SKU");
        return $handler->redirect_to(
            "/Fulfilment/PackingException/ViewContainer?container_id=$container_id"
        );
    } elsif ( $sku !~ /^\d+-\d+$/ ) {
        xt_warn("The SKU you scanned does not appear to be valid");
        return $handler->redirect_to(
            "/Fulfilment/PackingException/ViewContainer?container_id=$container_id"
        );
    }

    # Check we can find it
    my ($orphan) =
        # With the righ sku
        grep { $_->get_sku eq $sku }
        # Just the ones in our tote
        grep { $_->container_id eq $container_id }
        # Retrieve all orphaned items across channels
        map  { @$_ } values %{ get_orphaned_items( $handler->schema ) };

    unless ( $orphan ) {
        xt_warn("Unable to find an unexpected item with that SKU in this container");
        return $handler->redirect_to(
            "/Fulfilment/PackingException/ViewContainer?container_id=$container_id"
        );
    }

# Do the actual removal
    $container->remove_item({ orphan_item => $orphan });

# Redirect correctly
    # If the container is emtpy, send the user back to the Packing Exception
    # page
    my $type = $container->physical_type;
    if ( $container->is_empty() ) {
        xt_success(ucfirst($type)." $container_id should now be empty");
        return $handler->redirect_to( "/Fulfilment/PackingException" );
    } else {
        xt_success("$sku removed from $type $container_id");
        return $handler->redirect_to(
            "/Fulfilment/PackingException/ViewContainer?container_id=$container_id"
        );
    }
}

1;
