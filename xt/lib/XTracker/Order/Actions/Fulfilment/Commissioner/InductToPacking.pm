package XTracker::Order::Actions::Fulfilment::Commissioner::InductToPacking;
use NAP::policy "tt";

use XTracker::Handler;

use NAP::DC::Barcode::Container;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    return try {
        return _handler($handler);
    }
    catch {
        return $handler->fatal_and_redirect($_, "/Fulfilment/Commissioner");
    };
}

sub _handler {
    my ($handler) = @_;

    my $container_or_shipment_id = $handler->clean_body_param(
        "container_or_shipment_id",
    ) // "";
    my $is_container_in_cage = $handler->clean_body_param(
        "is_container_in_cage",
    ) // 0;

    my $container_row = get_container_row(
        $handler->{schema},
        $container_or_shipment_id,
    ) or return $handler->warn_and_redirect(
        "There is no Container/Shipment '$container_or_shipment_id'",
        "/Fulfilment/Commissioner",
    );

    my $container_id = $container_row->id;
    $container_row->packing_ready_in_commissioner
        or return $handler->warn_and_redirect(
            "The Shipments in Container '$container_id' aren't ready for Packing",
            "/Fulfilment/Commissioner",
        );

    return $handler->redirect_to(
        induction_url($container_id, $is_container_in_cage),
    );
}

sub induction_url {
    my ($container_id, $is_container_in_cage) = @_;
    $is_container_in_cage //= 0;

    return
          "/Fulfilment/Induction"
        . "?container_id=$container_id"
        . "&is_container_in_cage=$is_container_in_cage"
        . "&return_to_url=/Fulfilment/Commissioner"
        . "&is_force=1";
}

=head2 get_container_row($schema, $container_or_shipment_id) : $container_row | undef

Find either a Container or Shipment with $container_or_shipment_id. If
it's a Shipment, return any of its Containers.

Return undef if no Container/Shipment was found, or if the Shipment
isn't in any Container.

=cut

sub get_container_row {
    my ($schema, $container_or_shipment_id) = @_;

    # Try to inflate into a Barcode, but it's ok if we fail (might be
    # a Shipment id)
    try {
        $container_or_shipment_id = NAP::DC::Barcode::Container->new_from_barcode(
            $container_or_shipment_id,
        );
    };

    my $container_rs = $schema->resultset("Public::Container");
    return $container_rs->find_by_container_or_shipment_id(
        $container_or_shipment_id,
    ); # May be undef
}


