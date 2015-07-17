package XTracker::Order::Fulfilment::PlaceInPEOrphan;
use NAP::policy "tt";

use List::MoreUtils qw(
    any
    uniq
);

use NAP::DC::Barcode::Container;
use NAP::DC::Barcode::Container::Tote;

use XTracker::Handler;
use XTracker::Image;
use XTracker::Utilities                 qw( number_in_list );
use XTracker::Constants::FromDB         qw( :shipment_item_status :container_status );
use XTracker::Navigation                qw( build_packing_nav );
use XTracker::Error;

use XT::Data::PRL::Conveyor::Route::ToPackingException;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Packing';
    $handler->{data}{subsubsection} = 'Place in Packing Exception Tote';
    $handler->{data}{content}       = 'ordertracker/fulfilment/pipeo.tt';

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "/Fulfilment/Packing" } );
    # check for 'Set Packing Station' link
    my $sidenav = build_packing_nav( $handler->{schema} );
    if ( $sidenav ) {
        push(@{ $handler->{data}{sidenav}[0]{'None'} }, $sidenav );
    }

    # Get source container list
    $handler->{data}{source_containers} = ref($handler->{param_of}{source_containers}) ?
                                            $handler->{param_of}{source_containers} :
                                            [$handler->{param_of}{source_containers}];

    $handler->{data}{dest_containers} = ref($handler->{param_of}{dest_containers}) ?
                                            $handler->{param_of}{dest_containers} :
                                                defined $handler->{param_of}{dest_containers} ?
                                                    [$handler->{param_of}{dest_containers}] :
                                                    [];
    # validate "destination" and "source" containers,
    # as a result all "totes" down the line are NAP::Barcode::Container objects
    foreach my $container_set (qw/source_containers dest_containers/) {
        my $err;
        try {
            $handler->{data}{ $container_set } = [
                map { NAP::DC::Barcode::Container->new_from_id($_) }
                @{ $handler->{data}{ $container_set } }
            ];
            $err = 0;
        } catch {
            xt_warn(sprintf 'Failed to validate "%s", reason: %s', $container_set, $_);
            $err = 1;
        };
        return $handler->redirect_to( "/Fulfilment/Packing" ) if $err;
    }

    if (! @{$handler->{data}{source_containers}}) {
        xt_warn( "I can't find any tote with items to be dealt with. Please scan a tote...?");
        return $handler->redirect_to( "/Fulfilment/Packing" );
    }


    $handler->{param_of}{complete} ||= "";
    if ($handler->{param_of}{complete} eq 'complete') {
        # Analyse if we're only dealing with strayed items.

        # In case we're dealing with more than one tote
        foreach my $tote (@{ $handler->{data}{dest_containers} }) {

            my $container = $handler->{schema}->resultset('Public::Container')->find($tote);

            # This handler may be called PlaceInPEOrphan, but it's also used for cancelled
            # items from the empty tote page, so we need to send the container to packing
            # exception if it contains anything (cancelled shipment item or orphan item).
            if ($container->shipment_items->count || $container->contains_orphan_items) {

                # Only gets sent in PRL phase:
                XT::Data::PRL::Conveyor::Route::ToPackingException->new({
                    container_row => $container,
                })->send();

            }

            # IWS only needs to be sent a route_tote if the container only has orphan
            # items in it - if it's got cancelled items belonging to a shipment then
            # IWS already knows about it.
            if ($container->shipment_items->count == 0 && $container->contains_orphan_items) {
                # Should only get send in IWS phase (does this happen?):
                # Send message to INVAR
                $handler->msg_factory->transform_and_send(
                    'XT::DC::Messaging::Producer::WMS::RouteTote',{
                        container_id => $tote,
                        destination  => 'packing exception',
                    },
                );
            }
        }

        return $handler->redirect_to( "/Fulfilment/Packing/EmptyTote?"
                                          . join '&',
                                      map { "container_id=$_" }
                                          @{$handler->{data}{source_containers}}
                                      );
    }

    # User must have just landed here with a tote with some items to be orphaned.
    $handler->{data}{process} = 'sku';

    try {
        $handler->{schema}->txn_do(
            sub {
                _process_sku($handler);
                _process_peo_tote($handler);
            }
        );
    }
    catch {
        when (/is not a valid SKU/) {
            xt_warn("That sku is not valid. Please scan a new sku.");
        }
        when (/May not mix channels in one container/) {
            xt_warn("You can't mix channels in the same container.");
            # reset process so that user can scan another sku
            $handler->{data}{process} = 'sku';
        }
        default {
            xt_warn($_);
        }
    };

    _display_peo_tote($handler);
    return $handler->process_template( undef );
}


sub _process_sku {
    my ($handler) = @_;

    return unless defined $handler->{param_of}{sku};
    return unless $handler->{data}{process} eq 'sku';

    $handler->{data}{sku} = $handler->{param_of}{sku};
    $handler->{data}{sku} =~ s/\s+//g;

    # First search for item belonging to shipment
    my ($pid,$sid) = $handler->{data}{sku} =~ /^(\d+)-(\d+)$/;

    die sprintf("'%s' is not a valid SKU",$handler->{data}{sku})
        unless $sid and $pid;

    my $voucher_variant = $handler->{schema}->resultset('Voucher::Variant')
                 ->find_by_sku($handler->{data}{sku},undef,1);
    if ($voucher_variant && !$voucher_variant->product->is_physical){
        xt_warn("How exactly are you scanning a virtual voucher? Please scan something with a physical presence instead.");
        return;
    }

    # Check if this sku is associated with the shipment we've just packed
    $handler->{data}{shipment_item} = $handler->{schema}->resultset('Public::ShipmentItem')
        ->search({
            container_id => { -in => $handler->{data}{source_containers} },
            -or => [
                { 'variant.product_id' => $pid, 'variant.size_id' => $sid },
                { 'voucher_variant.voucher_product_id' => $pid },
            ],
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
        },{
            join => [ 'variant','voucher_variant' ],
            rows => 1,  # If there's two identical items we're picking just one.
        })->single;

    # Check if it might be a strayed sku

    # PEC TODO , this will need to be amended. PNDC will fix it for us ;)
    unless ($handler->{data}{shipment_item}) {
        $handler->{data}{orphan_item} = $handler->{schema}->resultset('Public::Variant')
            ->find_by_sku($handler->{data}{sku},undef,1);

        # It must be a voucher then
        if (!$handler->{data}{orphan_item}) {
            $handler->{data}{orphan_item} = $handler->{schema}->resultset('Voucher::Variant')
                ->find_by_sku($handler->{data}{sku},undef,1);
        }

        # die If we still can't find anything and it will be caught by catch.
        die "That is not a valid SKU" if !$handler->{data}{orphan_item};

    }

    $handler->{data}{process} = 'pe_tote';
}


sub _process_peo_tote {
    my ($handler) = @_;

    return unless defined $handler->{param_of}{pe_tote};
    return unless $handler->{data}{process} eq 'pe_tote';

    $handler->{data}{pe_tote} = $handler->{param_of}{pe_tote};

    # Validate scanned container
    my $tote;
    my $err;
    try {
        $tote = NAP::DC::Barcode::Container::Tote->new_from_id(
            $handler->{data}{pe_tote},
        );
        $err = 0;
    }
    catch {
        xt_warn($_);
        $err = 1;
    };
    return if $err;

    my $existing_tote_object = $handler->{schema}->resultset('Public::Container')->find($tote);
    if ($existing_tote_object &&
        $existing_tote_object->status_id != $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS &&
        $existing_tote_object->status_id != $PUBLIC_CONTAINER_STATUS__AVAILABLE){
        xt_warn("Tote '$tote' contains " . $existing_tote_object->status->name . " and cannot be used. Please choose another tote.");
        return;
    }

    # Safekeep the totes we're scanning stuff into

    my $srcs = $handler->{data}{source_containers};

    # is the tote one of the "source" ones?
    if (any {$_ eq $tote} @{$srcs}) {
        xt_warn('A shipment came in the tote you just scanned. Please choose another tote.');
        return;
    }

    # Process an orphan item

    # Item being processed is shipment_item
    if ($handler->{data}{shipment_item}) {

        # Prepare IWS message
        my $shipment_item = $handler->{data}{shipment_item};
        my $msg_params = {
            from  => { container_id      => $shipment_item->container_id,
                       stock_status => 'main' },
            to    => { container_id      => $tote,
                       stock_status => 'main' },
            items => [{
                sku      => $shipment_item->get_sku,
                quantity => 1,
                client   => $shipment_item->get_client()->get_client_code(),
            },],
        };

        $handler->{data}{shipment_item}->orphan_item_into( $tote );
        $handler->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::WMS::ItemMoved',{
                shipment_id => $handler->{data}{shipment_item}->shipment_id,
                %$msg_params,
            });
    }
    else {
        # Item is a strayed sku
        my $old_container_id = join(',', sort @{ $srcs });
        $handler->{schema}->resultset('Public::OrphanItem')
            ->create_orphan_item(
                $handler->{data}{sku},
                $tote,
                $old_container_id,
                $handler->{data}{operator_id},
            );
    }

    # Make sure we have no duplicates.
    $handler->{data}{dest_containers} = [ uniq @{ $handler->{data}{dest_containers} },$tote ];

    $handler->{data}{process} = 'sku';
}


sub _display_peo_tote {
    my ($handler) = @_;
    # Display already scanned shipment_items

    if (@{$handler->{data}{dest_containers}}) {
        $handler->{data}{orphan_items_in_tote} = [
            $handler->{schema}->resultset('Public::ShipmentItem')
            ->search({
                container_id => { -in => $handler->{data}{dest_containers} }
            })->all(),
            $handler->{schema}->resultset('Public::OrphanItem')
            ->search({
                container_id => { -in => $handler->{data}{dest_containers} }
            })->all,
        ];
    }
    my $images = [];

    foreach my $orphan_item ( @{ $handler->{data}{orphan_items_in_tote} } ){
        push @{ $images }, {
            product_id => $orphan_item->get_true_variant->product_id,
            live => 1,
        };
    }
    $handler->{data}{images}
        = XTracker::Image::get_image_list($handler->{schema}, $images,q{m});

}


1;
