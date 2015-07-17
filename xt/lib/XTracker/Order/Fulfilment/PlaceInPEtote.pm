package XTracker::Order::Fulfilment::PlaceInPEtote;
use NAP::policy "tt";

use NAP::DC::Barcode::Container;
use NAP::DC::Barcode::Container::Tote;
use XTracker::Handler;
use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Image;
use XTracker::Utilities qw(
                              number_in_list
                      );
use XTracker::Constants::FromDB qw(
                                      :shipment_item_status
                                      :shipment_status
                                      :shipment_class
                                      :container_status
                                      :note_type
                              );
use XTracker::Navigation qw(build_packing_nav);
use XTracker::Error;
use XTracker::Database::Container qw( :validation );
use List::MoreUtils qw(any);
use XT::Data::PRL::Conveyor::Route::ToPackingException;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Packing';
    $handler->{data}{subsubsection} = 'Place in Packing Exception Tote';
    $handler->{data}{content}       = 'ordertracker/fulfilment/pipe.tt';

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "/Fulfilment/Packing" } );
    # check for 'Set Packing Station' link
    my $sidenav = build_packing_nav( $handler->{schema} );
    if ( $sidenav ) {
        push(@{ $handler->{data}{sidenav}[0]{'None'} }, $sidenav );
    }

    if (!$handler->{param_of}{shipment_id}) {
        return $handler->redirect_to( "/Fulfilment/Packing" );
    }

    $handler->{param_of}{shipment_id} =~ s{\s+}{}g;

    $handler->{data}{shipment} = $handler->{schema}->resultset('Public::Shipment')
        ->find({ id => $handler->{param_of}{shipment_id} });

    if (!$handler->{data}{shipment}) {
        xt_warn("Unknown shipment $handler->{param_of}{'shipment_id'}");
        return $handler->redirect_to( "/Fulfilment/Packing" );
    }


    my $source_containers = [];
    if ($handler->{param_of}{source_containers}) {
        $source_containers = $handler->{param_of}{source_containers};
        if (!ref($source_containers)) {
            $source_containers = [$source_containers];
        }
    }
    else {
        $source_containers = [
            $handler->{data}{shipment}->containers->search({
                status_id => $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS,
            })->get_column('id')->all,
        ];
    }

    # We have no way of tracking which items we have scanned without passing
    # them back and forth in the template. It's pretty fugly I know, but we
    # used to live with the assumption that each pigeonhole contained one item
    # only, and now that's changed
    if ( $handler->{param_of}{scanned_ph_items} ) {
        $handler->{data}{scanned_ph_items} = $handler->{param_of}{scanned_ph_items};
        $handler->{data}{scanned_ph_items} = [$handler->{data}{scanned_ph_items}]
            unless ref $handler->{data}{scanned_ph_items};
    }

    # Convert $source_containers into objects
    my $err;
    try {
        $source_containers = [
            map { NAP::DC::Barcode::Container->new_from_id( $_ ) }
            @$source_containers
        ];
        $err = 0;
    }
    catch {
        xt_warn("Invalid Source Container: $_");
        $err = 1;
    };
    return $handler->redirect_to( "/Fulfilment/Packing" ) if $err;

    if ($handler->{param_of}{completed}) {
        if ($handler->{data}{shipment}->shipment_class_id != $SHIPMENT_CLASS__RE_DASH_SHIPMENT) {
            # don't send for re-shipments because IWS doesn't know they exist
            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::WMS::ShipmentReject',
                { shipment_id => $handler->{param_of}{shipment_id} }
            );
        }

        # Tell conveyor to route problem container(s) to Packing Exception area
        my $shipment_row = $handler->{data}{shipment};
        XT::Data::PRL::Conveyor::Route::ToPackingException->new({
            container_rows => [
                $shipment_row->containers->filter_packing_exception->all,
            ],
        })->send();

        # don't include pigeon holes because they can only contain one
        # item and the same pigeon hole has been used when sending to PE
        my @source_totes = grep { ! $_->is_type("pigeon_hole") } @$source_containers;

        # TODO: This bit of logic here is most likely broken... but I think we
        # need a separate ticket to deal with the empty tote scenario
        if (@$source_containers && !@source_totes) {
            # must've been a pigeonhole-only shipment, so we don't need
            # to check for anything else in totes or confirm anything's
            # empty
            xt_success("Packing of item" . (@$source_containers > 1 ? 's ' : ' ') . "in "
                . join(', ', @$source_containers) . " complete. Please scan a new container/shipment.");
            return $handler->redirect_to( "/Fulfilment/Packing");
        }

        return $handler->redirect_to(
            "/Fulfilment/Packing/CheckShipment?" . join(
                '&',
                map { "shipment_id=$_" } @source_totes,
            ),
        );
    }

    my @dest_containers = $handler->{data}{shipment}->non_canceled_items
        ->containers($PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS)
        ->get_column('id')->all;

    $handler->{data}{source_containers} = $source_containers;
    $handler->{data}{dest_containers} = \@dest_containers;

    $handler->{data}{show_in_source} = sub {
        my ($shipment_item, $scanned_ph_items) = @_;

        return 0 if $shipment_item->is_virtual_voucher;

        return 0 if ! number_in_list($shipment_item->shipment_item_status_id,
                                     $SHIPMENT_ITEM_STATUS__PICKED,
                                     $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION);

        my $container = $shipment_item->container;
        return 0 if ! $container;

        # Pigeonholes are more complicated as we can have picked/packing
        # exception items in the same pigeonhole, so just looking at the
        # container's status is not enough. We need this nasty extra logic.
        return $container->status_id == $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS
            unless $container->is_pigeonhole;

        return 1 unless @{$scanned_ph_items||[]};

        return !grep { $_ && $_ == $shipment_item->id } @$scanned_ph_items;
    };

    $handler->{data}{show_in_destination} = sub {
        my ($shipment_item, $scanned_ph_items) = @_;

        return 0 if $shipment_item->is_virtual_voucher;

        return 0 if ! number_in_list($shipment_item->shipment_item_status_id,
                                     $SHIPMENT_ITEM_STATUS__PICKED,
                                     $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                     $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
                                 );

        my $container = $shipment_item->container;
        return 1 if ! $container;

        return $container->status_id == $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS
            unless $container->is_pigeonhole;

        # Nasty pigeonhole logic, see show_in_source comment
        return 0 unless @{$scanned_ph_items||[]};

        return scalar grep { $_ && $_ == $shipment_item->id } @$scanned_ph_items;
    };

    $handler->{data}{process} = 'sku';

    try {
        $handler->{schema}->txn_do(
            sub {
                _process_sku($handler);

                try   { _process_pe_tote($handler) }
                catch { xt_warn($_)                };

                _check_completed($handler);
            }
        );
    }
    catch {
        xt_warn($_);
    };

    # freeze sticky page because PIPE is not complete
    my $sticky_id = $handler->{param_of}{shipment_id};
    my $sticky_obj = $handler->{schema}->resultset('Public::Shipment')->find($sticky_id);
    $handler->freeze_sticky_page( {
        sticky_class => 'Operator::StickyPage::PIPE',
        sticky_id => $sticky_id,
        signature_object => $sticky_obj,
    } );

    return $handler->process_template;
}

sub _process_sku {
    my ($handler) = @_;

    return unless defined $handler->{param_of}{sku};
    return unless $handler->{data}{process} eq 'sku';

    $handler->{data}{sku} = $handler->{param_of}{sku};
    $handler->{data}{sku} =~ s/\s+//g;

    return xt_warn("The sku entered ($handler->{data}{sku}) is not valid. Please try again.")
        unless $handler->{data}{sku} =~ m{^\d+-\d+$};

    my $item_rs = $handler->{data}{shipment}
        ->items_by_sku( $handler->{data}{sku} )
        ->items_in_container($handler->{data}{source_containers});

    # Exclude any already scanned PH items if we have any
    $item_rs = $item_rs->search({'me.id' => { q{!=} => $handler->{data}{scanned_ph_items} } })
        if $handler->{data}{scanned_ph_items};

    my @items = sort {
        # This will sort the list so that items without a failure reason come
        # first
        (!! $a->qc_failure_reason) <=> (!! $b->qc_failure_reason)
    } $item_rs->all;

    $handler->{data}{shipment_item} = $items[0];

    return xt_warn("The sku entered ($handler->{data}{sku}) could not be found. Please try again.")
        unless $handler->{data}{shipment_item};

    $handler->{data}{process} = 'pe_tote';

    return if defined $handler->{param_of}{pe_tote};

    if ($handler->{data}{shipment_item}->container->is_pigeonhole) {
        xt_success("Return item to pigeonhole ".$handler->{data}{shipment_item}->container->id);
    }

    return;
}

sub _process_pe_tote {
    my ($handler) = @_;

    return unless defined $handler->{param_of}{pe_tote};
    return unless $handler->{data}{process} eq 'pe_tote';

    $handler->{data}{pe_tote} = NAP::DC::Barcode::Container->new_from_id(
        $handler->{param_of}{pe_tote},
    );

    # different logic for totes and pigeon holes
    if ($handler->{data}{shipment_item}->container->is_pigeonhole()) {
        # container is pigeon hole
        xt_success('Ensure '.$handler->{data}{sku}.' has been returned to pigeon hole '.$handler->{data}{shipment_item}->container_id);

        # We switch the container's status as soon as the first item enters it,
        # even if it still contains 'source container' picked items
        $handler->{data}{shipment_item}->container->set_status({
            status_id => $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS,
        });

        # We need to track which items we've already scanned, so we know where
        # to display them in the tables in the template and to determine when
        # we've scanned everything we need to
        push @{$handler->{data}{scanned_ph_items}},
            $handler->{data}{shipment_item}->id;
    } else {
        # container is tote
        my $tote = $handler->{data}{pe_tote};
        my $srcs = $handler->{data}{source_containers}; # Barcode::Container objects

        # is the tote one of the "source" ones?
        if (any {$_ eq $tote} @{$srcs}) {
            return xt_warn('You must use a new tote.');
        }

        # must be a Tote, not just any Container
        $tote = NAP::DC::Barcode::Container::Tote->new_from_id($tote);

        # is the tote containing other stuff?
        my $shipments_in_tote = $handler->{schema}->resultset('Public::ShipmentItem')
            ->items_in_container(
                $tote,
                { exclude_shipment => $handler->{data}{shipment}->id },
            )->count();
        if ($shipments_in_tote > 0) {
            return xt_warn('The tote you scanned contain items from different shipments. Please choose another one.');
        }
        $handler->{data}{shipment_item}->packing_exception_into(
            $tote,
            $handler->{data}{operator_id},
        );
        # note - we don't need to tell IWS that we're moving items here as we're going to send
        # a shipment_reject message soon enough and that will update IWS to the location of all the shipment items
    }

    $handler->{data}{process} = 'sku';

    return;
}

sub _check_completed {
    my ($handler) = @_;

    my $items_to_move = $handler->{data}{shipment}->search_related(
        'shipment_items',
        {
            container_id => { -in => $handler->{data}{source_containers} },
            shipment_item_status_id => { -in => [
                $SHIPMENT_ITEM_STATUS__PICKED,
                $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
            ] },
        },
    )->count();

    if ($items_to_move - @{$handler->{data}{scanned_ph_items}||[]} == 0) {
        $handler->{data}{process} = 'completed';
    }

    return;
}

1;
