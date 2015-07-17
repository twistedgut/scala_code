package XTracker::Order::Fulfilment::PEScanItemIntoTote;
use NAP::policy "tt";

use NAP::DC::Barcode::Container;
use NAP::DC::Barcode::Container::PigeonHole;
use XTracker::Handler;
use XTracker::Error;
use XTracker::Database::Shipment    qw( get_shipment_item_info );
use XTracker::Database::Container   qw( :validation :naming );
use XTracker::Constants::FromDB     qw( :shipment_item_status );
use XTracker::Image; # get_images

my %situations = (
    'removeFaulty' => { name => 'Remove Faulty Item', continue_url => '/Fulfilment/Packing/ScanFaultyItem' }
);

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # Check shipment
    my $shipment = $handler->{schema}->resultset('Public::Shipment')->find($handler->{param_of}{shipment_id});
    unless ( $shipment ) {
        xt_warn("Shipment '$handler->{param_of}{shipment_id}' not found");
        return $handler->redirect_to( "/Fulfilment/PackingException" );
    }

    # check shipment_item
    my $shipment_item = $shipment->search_related('shipment_items',
        { id => $handler->{param_of}{shipment_item_id},}
    )->single;
    unless ($shipment_item){
        xt_warn("shipment item '$handler->{param_of}{shipment_item_id}' not found in shipment $handler->{param_of}{shipment_id}");
        return $handler->redirect_to( "/Fulfilment/Packing/CheckShipmentException?shipment_id=" . $shipment->id );
    }

    # check shipment item is in correct state
    if (
        $shipment_item->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION &&
        $shipment_item->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
    ){
        xt_warn(sprintf("Shipment item %s is not in a packing exception state so doesn't need fixing", $shipment_item->get_sku));
        return $handler->redirect_to( "/Fulfilment/Packing/CheckShipmentException?shipment_id=" . $shipment->id );
    }
    if (defined $shipment_item->container_id){
        xt_warn(sprintf("Shipment item %s is already in a container", $shipment_item->get_sku));
        return $handler->redirect_to( "/Fulfilment/Packing/CheckShipmentException?shipment_id=" . $shipment->id );
    }


    # Set up the navigation and template
    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Packing Exception';
    $handler->{data}{subsubsection} = 'Scan found item into tote';
    $handler->{data}{content}       = 'ordertracker/fulfilment/pe_scan_item_into_tote.tt';
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, {
        'title' => 'Back',
        'url'   => "/Fulfilment/Packing/CheckShipmentException?shipment_id=" .
            $shipment->id
    });

    # Save product data
    $handler->{data}{shipment}           = $shipment;
    $handler->{data}{shipment_item_id}   = $shipment_item->id;
    $handler->{data}{shipment_item_info} = get_shipment_item_info( $handler->{dbh}, $shipment->id )->{ $shipment_item->id };
    $handler->{data}{shipment_item_info}->{image} = get_images( {
        product_id => $shipment_item->product_id,
        live => 1,
        schema => $handler->{schema},
    } );


    # Deal with the SKU if we have it
    my $sku = $handler->{param_of}{sku};
    if ( defined $sku && $sku =~ m/\d/ ) {
        $sku =~ s/\s+//g;
        if ( $sku eq $shipment_item->get_sku ) {
            $handler->{data}->{sku} = $sku;
            if ($shipment_item->qc_failure_reason) {
                $handler->{data}->{old_container_id} = $shipment_item->old_container_id;
            }
        } else {
            xt_warn("The SKU you entered does not match the target item's SKU");
        }
    }

    my $container_id = $handler->{param_of}{container_id} // "";

    # If there is an old Container and it is a PigeonHole, or undef
    my $old_pigeon_hole_container_id = eval {
        NAP::DC::Barcode::Container::PigeonHole->new({
            scanned_barcode => $handler->{data}->{old_container_id},
        })
    };
    if ($sku && !$container_id) {
        # If it was in a pigeon hole before, tell them they should return
        # it to the same one. It should be guaranteed empty, because IWS
        # shouldn't reuse it for another shipment until we tell it this
        # shipment is all finished.
        if ($old_pigeon_hole_container_id) {
            xt_success("Return item to pigeon hole $old_pigeon_hole_container_id");
        }
    }

    if ($handler->{data}->{sku} && $container_id =~ m/\w/) {
        my $err;
        try {
            # validate container
            $container_id = NAP::DC::Barcode::Container->new_from_id($container_id);
            if ( ! $container_id->is_type("any_tote", "pigeon_hole") ) {
                die "invalid container type";
            }

            if (
                     $old_pigeon_hole_container_id
                && ( $old_pigeon_hole_container_id ne $container_id ),
            ) {
                die "You must return the item to its original pigeon hole: $old_pigeon_hole_container_id";
            }

            # try packing it
            $handler->{schema}->txn_do(sub{
                # put it in a tote and set it to picked
                $shipment_item->packing_exception_into($container_id);

                if ( $shipment_item->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ) {
                    $shipment_item->update_status( $SHIPMENT_ITEM_STATUS__PICKED, $handler->operator_id );
                } elsif ( $shipment_item->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING ) {
                    $shipment_item->update({ qc_failure_reason => '' });
                }

                # Tell Invar that we found the item by sending an 'item moved' message.
                # we'll tell it we moved it from 'nowhere' to the tote
                $handler->msg_factory->transform_and_send(
                    'XT::DC::Messaging::Producer::WMS::ItemMoved',
                    {
                        shipment_id => $shipment->id,
                        to    => { container_id => $container_id,
                                   stock_status => 'main' },
                        items => [{
                            sku      => $shipment_item->get_sku,
                            quantity => 1,
                            client   => $shipment_item->get_client()->get_client_code(),
                        },],
                    }
                );
            });
            xt_success('Successfully placed back into ' . $container_id->name);
            $err = 0;
        }
        catch {
            $err = 1;
            when (/invalid container type|Unrecognized barcode format/) {
                xt_warn("Invalid container id (it should begin with 'M', 'T', or 'PH')");
            }
            when (/must return the item to its original pigeon hole/) {
                xt_warn("$_");
            }
            default {
                xt_warn("Error updating shipment item $_");
            }
        };
        return $handler->redirect_to( "/Fulfilment/Packing/CheckShipmentException?shipment_id=" . $shipment->id ) unless $err;
    }


    # Render, return
    return $handler->process_template;
}

1;
