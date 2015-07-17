package XTracker::Order::Fulfilment::PrePackShipment;
use NAP::policy 'tt';

use NAP::DC::Barcode::Container;
use XTracker::Config::Local qw/ config_var /;
use XTracker::Logfile 'xt_logger';
use XTracker::Handler;
use XTracker::Image;
use XTracker::Database::Shipment        qw( :DEFAULT :carrier_automation );
use XTracker::Database::Address;
use XTracker::Database::Product         qw (get_product_channel_info);
use XTracker::Database::StockTransfer   qw( get_stock_transfer );
use XTracker::Database::Order;
use XTracker::Database::Container       qw(:naming :validation);
use XTracker::Utilities                 qw( parse_url url_encode number_in_list );
use XTracker::Constants::FromDB qw(
    :business
    :container_status
    :note_type
    :shipment_item_status
);
use XTracker::Navigation                qw( build_packing_nav );
use XTracker::Error;
use MooseX::Params::Validate;
use XT::Data::Types qw/PositiveDatabaseInt/;

use List::MoreUtils qw ( uniq );

use URI;
use URI::QueryParam;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    my $msg_factory = $handler->msg_factory;
    my $operator_id = $handler->operator_id;

    $handler->{data}->{section}       = 'Fulfilment';
    $handler->{data}->{subsection}    = 'Packing';
    $handler->{data}->{subsubsection} = 'Check Shipment';
    $handler->{data}->{content}       = 'ordertracker/fulfilment/prepackshipment.tt';

    # back link in left nav
    push @{ $handler->{data}->{sidenav}->[0]->{None} }, {
        'title' => 'Back',
        'url' => "/Fulfilment/Packing",
    };

    # check for 'Set Packing Station' link
    my $sidenav = build_packing_nav( $schema );
    if ( $sidenav ) {
        push(@{ $handler->{data}->{sidenav}->[0]->{None} }, $sidenav );
    }

    # check to see if operator has a packing printer assigned and set param if so FELIX
    if (my $pref = $handler->operator->operator_preference ) {
        if ( my $packing_printer = $pref->packing_printer ) {
            $packing_printer =~ s/\s//g;
            $handler->{data}->{packing_printer} = $packing_printer;
        }
    }

    # we asked to scan a SKU from a tote, but it's empty!
    # QC fail all remaining items in all remaining shipments as "missing"
    if (my $empty_tote = $handler->{param_of}->{empty_tote}) {
        # make sure that passed ID for emty tote is a valide container ID
        my $err;
        try {
            $empty_tote = NAP::DC::Barcode::Container->new_from_id($empty_tote);
            $err=0;
        } catch {
            $err=1;
            xt_warn('Got invalid ID for empty tote: ' . $_);
        };
        return $handler->redirect_to('/Fulfilment/Packing') if $err;

        my @failed_shipment_ids =
            mark_items_remaining_in_tote_as_missing(
                $schema,
                $empty_tote,
                $operator_id,
            );

        for my $failed_id (@failed_shipment_ids) {
            _send_after_class_check({
                schema      => $schema,
                msg_factory => $msg_factory,
                msg_type    => "XT::DC::Messaging::Producer::WMS::Shipment$_",
                operator_id => $operator_id,
                shipment_id => $failed_id,
            }) for qw{Received Reject};
        }

        xt_info('Tote is confirmed as empty');
        return $handler->redirect_to( "/Fulfilment/Packing" );
    }

    # we need a shipment id, container id, or container id and sku -
    # otherwise redirect back to packing overview
    if (!$handler->{param_of}->{shipment_id}) {
        return $handler->redirect_to( "/Fulfilment/Packing" );
    }

    if (ref $handler->{param_of}->{shipment_id}) {
        for my $id (@{$handler->{param_of}->{shipment_id}}) {
            $id =~ s{\s+}{}g;
        }
    }
    else {
        $handler->{param_of}->{shipment_id} =~ s{\s+}{}g;
    }

    # if an RTV shipment id was entered (prefixed 'RTVS-'), redirect accordingly
    if ( $handler->{param_of}->{shipment_id} =~ m{\A\s*(RTVS-\d+)\s*\z}xms ) {
        my $rtv_shipment_id = $1;
        return $handler->redirect_to( "/RTV/PackRTV?rtv_shipment_id=$rtv_shipment_id" );
    }

    my $ids = $handler->{param_of}->{shipment_id};
    $ids = ref($ids) ? $ids : [$ids];

    # Was it a shipment id or a tote scanned? Implicitly, below, we used the
    # logic that all numerics are treated as shipment-ids, and anything else is
    # treated as a tote id, so replicate. Doing this once so that if we change
    # the logic, we can update it in one place. You may also note that as
    # the shipment_id can be an arrayref, is_container_id will be set in that
    # case. This is happy coincidence, as only multiple container ids should be
    # set (and never multiple shipment ids)
    my $is_container_id =
        $handler->{param_of}->{shipment_id} =~ m/^\d+$/ ? 0 : 1;

    # Sanity check that, as per DCEA-LIVE-94...
    if ( $is_container_id ) {
        my @invalid_ids = grep {
            ! eval { NAP::DC::Barcode::Container->new_from_id($_) }
        } @$ids;
        if ( @invalid_ids ) {
            xt_warn(
                "The following items are neither valid tote IDs or shipment IDs: "
                . join(', ', @invalid_ids),
            );
            return $handler->redirect_to('/Fulfilment/Packing');
        }

        $ids = [
            map {  NAP::DC::Barcode::Container->new_from_id($_) } @$ids,
        ];

        # handle case when user for some weird reasons decided to scan hooks
        if (my @scanned_hooks = grep {$_->type eq 'hook'} @$ids) {
            xt_warn(
                sprintf "The hook '%s' is in the MTS area. The garment on "
                    . "the hook needs to be placed in a tote at GOH Integration", $_
            ) for @scanned_hooks;
            return $handler->redirect_to('/Fulfilment/Packing');
        }

        my $container_rs = $schema->resultset('Public::Container')->search({
            "me.id" => { -in => $ids },
        });

        if ($handler->prl_rollout_phase) {
            # Check the Containers scanned are ready for packing
            # Note: $container_rs here actually only contains the scanned container id, so
            # we need to go via ->shipments to get all the associated containers
            my $associated_container_rs = $container_rs->shipments->containers;

            my $can_be_packed = _check_allocation_status($handler, $associated_container_rs);
            return $handler->redirect_to('/Fulfilment/Packing') unless ($can_be_packed);
        }

        # Since these Containers are at Packing, they aren't in the other
        # known physical places; clear it.
        $container_rs->clear_physical_place();
    }

    # For PRL-enabled XT:
    # If the shipment_id param validates as a container barcode, they probably
    # scanned it just now, so we mark it as having arrived at the pack lane.
    # In the normal case, this won't have any effect because we would already
    # have marked it as arrived when we received a route_response for it, we're
    # only doing it here too as a backup in case someone ended up walking the
    # tote over instead of putting it on the conveyor.
    my $scanned_container = eval {
        NAP::DC::Barcode::Container->new_from_barcode(
            $handler->{param_of}{shipment_id}
        );
    };
    if ($scanned_container) {
        my $container_row = $schema->resultset('Public::Container')->find(
            $scanned_container
        );
        $container_row->maybe_mark_has_arrived if ($container_row);
    }

    my $is_shipment_id = $is_container_id ? 0 : 1;

    my $shipment_object;
    if ($is_shipment_id) {
        my $err;
        try {
            my ($shipment_id) = validated_list([
                    shipment_id => $handler->{param_of}->{shipment_id}
                ],
                shipment_id => { isa => PositiveDatabaseInt, required => 1 },
                # MooseX::Params::Validate uses caller_cv as a cache
                # key for the compiled validation constraints. 'try'
                # takes a coderef, that in this case is a
                # garbage-collectable anonymous sub that closes over
                # some variables; since it's a closure, it gets
                # re-allocated every time. A new sub (anonymous or
                # not) created after this one is called may well end
                # up at the same memory address, thus colliding in the
                # MX:P:V cache; let's provide a hand-made key to make
                # sure we never collide
                MX_PARAMS_VALIDATE_CACHE_KEY => __FILE__.__LINE__,
            );
            $shipment_object = $schema->resultset('Public::Shipment')->find({
                id => $shipment_id,
            });
            $err=0;
        } catch {
            $err=1;
            xt_warn('The submitted shipment-id was invalid');
        };
        return $handler->redirect_to('/Fulfilment/Packing') if $err;
    }

    if ($shipment_object && $shipment_object->has_containers) {
        my $container_rs = $shipment_object->containers;
        my $can_be_packed = _check_allocation_status($handler, $container_rs);
        return $handler->redirect_to('/Fulfilment/Packing') unless ($can_be_packed);
    }


    # yes, we test for *not* packed. if no item has been packed, and
    # no item is in containers, the shipment is still being picked. If
    # it's (partially) packed, we assume the packer wants to continue
    # packing from where they left off
    # and if it's a reshipment, we want to let them carry on
    if ($shipment_object &&
        !$shipment_object->has_containers &&
        !$shipment_object->is_shipment_packed &&
        !$shipment_object->is_reshipment){
        xt_warn("This shipment should not be at packing, as the shipment items are not in containers (and anyway, you should be scanning container barcodes not shipment ids!)");
        return $handler->redirect_to('/Fulfilment/Packing');
    }

    if ($shipment_object && $shipment_object->is_dispatched){
        xt_warn("This shipment is already dispatched");
        return $handler->redirect_to('/Fulfilment/Packing');
    }

    # id of the shipment we're packing
    my @shipment_ids = get_shipment_ids_from_id_or_container_and_sku(
        $schema,
        $is_container_id ? $ids : $ids->[0],
        $handler->{param_of}->{sku},
        {
            exclude_cancelled => 1,
            exclude_cancelled_items => 1,
        }
    );

    # send shipment_received for all cancelled shipments, because it won't get done elsewhere
    {
        my @shipment_ids_cancelled = get_shipment_ids_from_id_or_container_and_sku(
            $schema,
            $is_container_id ? $ids : $ids->[0],
            $handler->{param_of}->{sku},
            { only_cancelled => 1, }
        );
        foreach my $shipment_id (@shipment_ids_cancelled) {
            _send_after_class_check({
                schema      => $schema,
                msg_factory => $msg_factory,
                msg_type    => "XT::DC::Messaging::Producer::WMS::ShipmentReceived",
                operator_id => $operator_id,
                shipment_id => $shipment_id,
            });
        }

    }

    my @shipments_at_pe;my @shipments;
    for my $sid (@shipment_ids) {
        my $s = $schema->resultset('Public::Shipment')->find($sid);
        if ( $s->is_at_packing_exception ) {
            push @shipments_at_pe,$s;
        }
        else {
            push @shipments,$s;
        }
    }

    # get the container resultset we're talking about - from the container id(s) or shipment id.
    if ($is_container_id && scalar @$ids == 1 && scalar @shipments == 1) {
        # multi shipments will only be in one container,
        # but if just one shipment there may be other containers associated
        push(
            @$ids,
            map { NAP::DC::Barcode::Container->new_from_id($_) }
            $shipments[0]->container_ids
        );
        @$ids = uniq @$ids;

        # Nuno says:
        # "For combined Pigeon Hole and Tote shipments, when a pigeon hole is scanned,
        # an additional message needs to be displayed"
        # so we don't have much choice but to do that check here
        if (!$shipments[0]->is_pigeonhole_only && $ids->[0]->is_type("pigeon_hole")) {
            $handler->{data}->{extra_message} = "You have scanned the Pigeon Hole barcode without scanning a tote. Please ensure you have all Totes for this shipment present at Packing. ";
        }
    }
    my $container_rs = $is_container_id ?
        $schema->resultset('Public::Container')->search({
            "me.id" => { -in => $ids },
        })
        :
        $schema->resultset('Public::Container')->search(
            { 'shipment_items.shipment_id' => $ids->[0] },
            { join => 'shipment_items' }
        );

    # they scanned a PE container, tell them to send it away
    if ($is_container_id && $container_rs->count==1
            && $container_rs->reset->first->status_id == $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS) {
        my $id = $container_rs->reset->first->id;
        xt_warn("Please send the container $id to the packing exception desk, then scan another one");
        return $handler->redirect_to('/Fulfilment/Packing');
    }

    if ($is_container_id && @shipments_at_pe && !@shipments) { # the !@shipments is probably not needed
        xt_warn("Please continue scanning item(s) into new tote(s) and send to the packing exception desk");
        return $handler->redirect_to('/Fulfilment/Packing/PlaceInPEtote?shipment_id='.$shipments_at_pe[0]->id);
    }

    # whole load of reasons to redirect the user or generally change process.
    if ( $is_shipment_id && $shipment_object && $shipment_object->is_cancelled ){
        # found shipment but it's cancelled
        _send_after_class_check({
            schema      => $schema,
            msg_factory => $msg_factory,
            msg_type    => "XT::DC::Messaging::Producer::WMS::ShipmentReceived",
            operator_id => $operator_id,
            shipment_id => $shipment_object->id,
        });
        xt_warn("That shipment has been cancelled, please try another");
        return $handler->redirect_to( "/Fulfilment/Packing" );
    }

    if (!@shipments && $is_shipment_id && !$handler->{param_of}->{sku}) {
        # looks like they entered a shipment_id (rather than a container_id), and we couldn't find it
        xt_warn("Unknown shipment or container $handler->{param_of}->{shipment_id}");
        return $handler->redirect_to( "/Fulfilment/Packing" );
    }

    if (!@shipments && $is_container_id && !$handler->{param_of}->{sku}) {
        # looks like a tote which we think is empty. Or only contains cancelled shipments.
        # Get them to confirm that it is empty.
        # *UNLESS* it's a transfer shipment (sample), or only had pigeon hole
        # items, in which case we don't ever ask them to confirm it's empty
        my $pigeonhole_only = 1;
        my @ph_ids_for_pe;
        foreach my $container_id (@$ids) {
            if ($container_id->is_type("pigeon_hole")) {
                my $container = $schema->resultset('Public::Container')->find($container_id);
                if ($container && ($container->status_id == $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS)) {
                    $container->update({
                        'status_id' => $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS,
                    });
                    push @ph_ids_for_pe, $container_id;
                }
            } else {
                $pigeonhole_only = 0;
            }
        }
        if ($pigeonhole_only) {
            # Tell the user something, unless they were just redirected
            # here after the end of packing by the template js
            if ($handler->{param_of}->{auto}) {
                if ($handler->{param_of}->{auto} eq 'completed') {
                    my $message = "Packing of item".(@$ids > 1 ? 's ' : ' ')." in pigeon hole" . (@$ids > 1 ? 's ' : ' ') . join(', ', @$ids) . " complete. ";
                    if (@ph_ids_for_pe) {
                        $message .= "Please take barcode".(@ph_ids_for_pe > 1 ? 's ' : ' ')." for ".join(', ', @ph_ids_for_pe) ." to Packing Exception, then scan a new container.";
                    } else {
                        $message .= "Please set aside and scan a new container.";
                    }
                    xt_success($message);
                }
            } else {
                xt_warn ("This pigeon hole is not associated with a shipment. Please ensure the item has been returned to the same pigeon hole, then take the pigeon hole barcode to packing exception.");
            }
            return $handler->redirect_to( "/Fulfilment/Packing" );

        }
        return $handler->redirect_to( "/Fulfilment/Packing" )
            if ($handler->{param_of}->{was_transfer_shipment});

        # DCEA-1658 - we'll get here if a shipment is cancelled but some
        # of its shipment_items are picked. this should never happen but
        # sometimes it does.
        if ($container_rs->reset->contains_packable) {
            $container_rs->reset;
            while ( my $container = $container_rs->next ) {
                $container->update({
                    'status_id' => $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS,
                });
                my $id = $container->id;
                if ($container->is_pigeonhole) {
                    xt_warn ("This shipment contains items in an incorrect state. Please return the item to pigeon hole $id, send the pigeon hole barcode to the packing exception desk, then scan another container.");
                } else {
                    xt_warn ("This shipment contains items in an incorrect state. Please send the container $id to the packing exception desk, then scan another one.");
                }
            }
            return $handler->redirect_to( "/Fulfilment/Packing" );
        }

        return $handler->redirect_to( "/Fulfilment/Packing/EmptyTote?".
                         join '&', map {"container_id=$_"} @$ids );
    }

    if (@shipments && $is_container_id && !$container_rs->contains_packable ){
        # may know of shipment items in the tote(s), but they're not in
        # packable state so pretend to packer that we think the tote is empty
        # *UNLESS* it's a transfer shipment (sample) in which case we don't
        # ever ask them to confirm it's empty
        return $handler->redirect_to( "/Fulfilment/Packing" )
            if $handler->{param_of}->{was_transfer_shipment};
        foreach my $shipment_object(@shipments) {
            _send_after_class_check({
                schema      => $schema,
                msg_factory => $msg_factory,
                msg_type    => "XT::DC::Messaging::Producer::WMS::ShipmentReceived",
                operator_id => $operator_id,
                shipment_id => $shipment_object->id,
            });
        }
        return $handler->redirect_to( "/Fulfilment/Packing/EmptyTote?".
                         join '&', map {"container_id=$_"} @$ids );
    }

    if (!@shipments && $handler->{param_of}->{sku}){
        # Must have entered a container_id with multiple shipments in it
        # except the variant they then went on to scan is not part of a shipment in that tote
        xt_warn("That item doesn't seem to belong to any shipment. Please put the item back and scan another item.");
        return $handler->redirect_to( "/Fulfilment/Packing?".
                                       join '&', map {"container_id=$_"} @$ids);
    }

    if (@shipments>1 && !$handler->{param_of}->{sku}) {
        # multiple shipments in container, no SKU scanned, redirect to scan it
        xt_info("This tote contains more than one shipment, please scan an item to select the shipment you want to pack");
        # if it's a sample transfer, we don't want to display the "This tote is empty" option later
        my $extra = $shipments[0]->is_transfer_shipment ? '&istransfer=1' : '';
        return $handler->redirect_to( "/Fulfilment/Packing?container_id=".
                                      $handler->{param_of}->{shipment_id} . $extra);
    }

    if ($handler->{param_of}->{sku}){
        # Check that the current SKU being dealt with hasn't been canceled.
        my ($pid,$sid)=split /-/,$handler->{param_of}->{sku};

        my $canceled_item = $schema
        ->resultset('Public::Variant')
        ->search({ product_id => $pid,size_id => $sid })
        ->search_related('shipment_items',{
            container_id => $handler->{param_of}->{shipment_id},
            shipment_item_status_id => { -in => [
            $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
            $SHIPMENT_ITEM_STATUS__CANCELLED,
            ]},
        })->count;

        if ($canceled_item){
            xt_warn("That item doesn't seem to belong to any shipment. Please put the item back and scan another item.");
            return $handler->redirect_to( "/Fulfilment/Packing?container_id=".
                                        $handler->{param_of}->{shipment_id} );
        }
    }

    # if the SKU has been scanned, and we still have multiple
    # shipments, it means that the (identical) items are
    # interchangeable, just pick a shipment
    $handler->{data}->{shipment_id} = $shipments[0]->id;
    $handler->{data}->{shipment}    = $shipments[0];
    my $shipment_obj = $handler->{data}->{shipment};

    if ($shipment_obj->has_packing_started) {
        if ( $shipment_obj->pack_status->{pack_complete} ) {
            xt_warn("Shipment " . $shipment_obj->id . " has already been packed.");
            return $handler->redirect_to('/Fulfilment/Packing');
        };
        xt_success('Packing resumed for this order');
        return $handler->redirect_to( "/Fulfilment/Packing/PackShipment".
            "?shipment_id=".$shipment_obj->id.
            "&packing_printer=".($handler->{data}->{packing_printer}||"")
        );
    }

    # WHM-105
    # Container-accumulator zone! If there are more than 1 containers in the
    # order, redirect the user until they've scanned them all.
    my @packable_containers = $shipment_obj->packable_container_ids;

    if ( $is_container_id && @packable_containers > 1 ) {
        # Get a list of totes we're willing to accept
        my %packable = map { $_ => 1 } @packable_containers;

        # Check the container the user provided.
        my $primary_container;
        try {
            $primary_container = NAP::DC::Barcode::Container->new_from_barcode($handler->{param_of}->{shipment_id});
        } catch {
            xt_warn( $handler->{param_of}->{shipment_id}." is not a valid container code: $_" );
            # Don't return yet, we'll carry on to the accumulator logic later.
        };
        my %seen;
        # If it's a tote with orientation, the key we want to use in %seen
        # is the id without the orientation char.
        $seen{$primary_container} = 1 if ($primary_container);

        # Get a list of previous containers provided by the user.
        my @other_containers = $handler->param_as_list('scanned_id');

        # We might be here because they just scanned another one on the accumulator page -
        # if so, check that one.
        if ($handler->{param_of}->{scanned_barcode}) {
            my $next_container;
            try {
                $next_container = NAP::DC::Barcode::Container->new_from_barcode($handler->{param_of}->{scanned_barcode});
            } catch {
                xt_warn( $handler->{param_of}->{scanned_barcode}." is not a valid container code: $_" );
                # Don't return yet, we'll carry on to the accumulator logic later.
            };
            # Add it to the list
            push @other_containers, $next_container if ($next_container);
            # For PRL-enabled XT:
            # Mark the container as having arrived at the pack lane.
            my $container_row = $schema->resultset('Public::Container')->find($next_container);
            $container_row->maybe_mark_has_arrived;
        }

        # If they're valid, add them to %seen, otherwise, skip them and complain
        for my $container ( @other_containers ) {
            $container =~ s/\s//g;

            my $container_is_valid;
            try {
                $container = NAP::DC::Barcode::Container->new_from_id($container);
                $container_is_valid = 1;
            };
            unless ( $container_is_valid ) {
                xt_warn( "$container is not a valid container code" );
                next;
            }

            unless ( $packable{ $container } ) {
                xt_warn( "Container $container is not associated with this shipment" );
                next;
            }

            $seen{ $container }++;
        }

        # Get a list of one we're still waiting for
        my @outstanding = grep { ! $seen{$_} } @packable_containers;

        # Redirect to the accumulator if there are any outstanding
        if ( @outstanding ) {
            my $accumulator_url = URI->new('/Fulfilment/Packing/Accumulator');
            $accumulator_url->query_param( shipment_id  => $shipment_obj->id );
            $accumulator_url->query_param( container_id => $handler->{param_of}->{shipment_id} );
            $accumulator_url->query_param( outstanding  => @outstanding      );
            $accumulator_url->query_param( scanned      => @other_containers );
            return $handler->redirect_to( $accumulator_url );
        }
    }

    # we can send this message multiple times - it's fine.
    _send_after_class_check({
        schema      => $schema,
        msg_factory => $msg_factory,
        msg_type    => "XT::DC::Messaging::Producer::WMS::ShipmentReceived",
        operator_id => $operator_id,
        shipment_id => $shipment_obj->id,
    });

    my $reject_shipment = 0;


    # get shipment info
    $handler->{data}->{shipment_info}         = get_shipment_info( $dbh, $shipment_obj->id );
    $handler->{data}->{shipment_address}      = get_address_info( $dbh, $handler->{data}->{shipment_info}->{shipment_address_id} );
    $handler->{data}->{orders_id}             = get_shipment_order_id( $dbh, $shipment_obj->id );
    $handler->{data}->{shipment_item_info}    = get_shipment_item_info( $dbh, $shipment_obj->id );
    my $print_docs_info  = $shipment_obj->picking_print_docs_info();

    if ($shipment_obj->has_gift_messages() && $shipment_obj->can_automate_gift_message()) {

        try {
            $handler->{data}->{gift_messages} = $shipment_obj->get_gift_messages();
        } catch {
            # To be honest, this exception is unlikely to occur because the image/problem
            # should have been resolved at picking where accessing/printing the image is
            # crucial. Still... lets not break the page.
            xt_logger->warn("Cant retrieve Gift Message image: $_");
        };
    } else {
        # remove from print docs and don't show in additional items
        delete($print_docs_info->{'GiftMessage'});
    }

    $handler->{data}->{shipment_extra_items}  = $print_docs_info;

    my $channel_id;
    # check if customer order
    if ( $handler->{data}->{orders_id} ) {
        $handler->{data}->{order_info}        = get_order_info( $dbh, $handler->{data}->{orders_id} );
        $handler->{data}->{sales_channel}     = $handler->{data}->{order_info}->{sales_channel};
        $channel_id                         = $handler->{data}->{order_info}->{channel_id};
    }
    # must be a stock transfer shipment
    else {
        $handler->{data}->{stock_transfer_id} = get_shipment_stock_transfer_id( $dbh, $shipment_obj->id );
        $handler->{data}->{stock_transfer}    = get_stock_transfer( $dbh, $handler->{data}->{stock_transfer_id} );
        $handler->{data}->{sales_channel}     = $handler->{data}->{stock_transfer}->{sales_channel};
        $channel_id                         = $handler->{data}->{stock_transfer}->{channel_id};
    }

    # check if there are any Physical Vouchers requiring QC
    my $pack_qc = 0;
    foreach my $item_id ( keys %{ $handler->{data}->{shipment_item_info} } ) {
        my $item    = $handler->{data}->{shipment_item_info}->{ $item_id };
        # is it a non-cancelled voucher
        if ( $item->{voucher} &&
             $item->{shipment_item_status_id} != $SHIPMENT_ITEM_STATUS__CANCELLED &&
             $item->{shipment_item_status_id} != $SHIPMENT_ITEM_STATUS__CANCEL_PENDING) {

            if ( $item->{is_physical} && !$item->{voucher_code_id} ) {
                # it's a physical voucher and has no code assigned
                $pack_qc++;
            }
            else {
                # it's a virtual voucher and check it has a code
                if ( !$item->{voucher_code_id} ) {
                    $reject_shipment    = 1;
                }
            }
        }
    }

    # if packing station required but not set or packing station no longer active, redirect to
    # packing overview with appropriate error message
    my $ps_check    = check_packing_station( $handler, $shipment_obj->id, $channel_id );
    if ( !$ps_check->{ok} ) {
        # go back to Fulfilment/Packing
        xt_warn($ps_check->{fail_msg});
        return $handler->redirect_to( '/Fulfilment/Packing' );
    }


    my $ship_info   = $handler->{data}->{shipment_info};

    # work out if shipment ready to be packed
    my %containers;

    foreach my $ship_item_id ( keys %{ $handler->{data}->{shipment_item_info} } ) {

        my $item_info   = $handler->{data}->{shipment_item_info}->{$ship_item_id};

        # we don't always have a container ID...
        if ( exists $item_info->{container_id} && $item_info->{container_id} ) {
            my $container_id = $item_info->{container_id};
            my $container = $schema->resultset('Public::Container')->find($container_id);

            # add to set if in container and not PE tote
            $containers{$container_id}=undef
                if ($container &&
                    !$container->is_packing_exception &&
                    !$container->is_superfluous);

            if ($container && $container->place && ($container->place eq get_commissioner_name)){
                if ($container->is_tote) {
                    # totes are (currently) the only kind of container that we want to
                    # ask them to go and get from the commissioner
                    $handler->{data}->{container_place}->{$container_id} = $container->place;
                }
                # TODO: DCEA-1295 do we want to remove ph containers from commissioner too?
                $container->remove_from_commissioner; # bit of a cheat as we haven't varified that they have really got it. But good enough
            }
        }

        # find out if the item is a Virtual Voucher
        if ( $item_info->{voucher} && !$item_info->{is_physical} ) {
            # if it is delete it from the list of items that will
            # be displayed in the packing pages
            delete $handler->{data}->{shipment_item_info}->{$ship_item_id};
            next;
        }

        $handler->{data}->{shipment_item_info}->{$ship_item_id}->{image} = get_images({
            product_id => $item_info->{product_id},
            live => 1,
            schema => $schema,
        });

        # get all channel data for product
        my (undef, $channel_info) = get_product_channel_info($dbh, $item_info->{product_id});

        # work out 'active' channel, and pass it to "view" only if it exists
        my $active_channel;
        my $product = $schema->resultset('Public::Product')->find($item_info->{product_id});
        $active_channel = $product->get_product_channel() if $product;

        if ($active_channel) {
            $handler->{data}->{shipment_item_info}->{$ship_item_id}->{active_channel} =
                $channel_info->{ $active_channel->channel->name() };
        }

        $handler->{data}->{shipment_item_info}->{$ship_item_id}->{ship_att}
            = get_product_shipping_attributes($dbh, $item_info->{product_id} );

        try {
            # get ship restrictions for the product
            my $ship_restrictions = $product->get_shipping_restrictions_status;
            $handler->{data}->{shipment_item_info}->{$ship_item_id}->{ship_restriction}->{is_hazmat}
                = $ship_restrictions->{is_hazmat};
            $handler->{data}->{shipment_item_info}->{$ship_item_id}->{ship_restriction}->{is_aerosol}
                = $ship_restrictions->{is_aerosol};
            $handler->{data}->{shipment_item_info}->{$ship_item_id}->{ship_restriction}->{is_hazmat_lq}
                = $ship_restrictions->{is_hazmat_lq};
        } catch {
            warn 'Product id is a voucher, no shipping restrictions';
        };
    }

    $handler->{data}->{pack_status} = $shipment_obj->pack_status;
    my $pack_status = $handler->{data}->{pack_status};

    $handler->{data}->{containers} = [ sort keys %containers ];

    # Retrieve any notes to do with packing exceptions
    $handler->{data}->{shipment_packing_exception_notes} = [
        $handler->{schema}->resultset('Public::ShipmentNote')->search(
                {
                    shipment_id  => $shipment_obj->id,
                    note_type_id => $NOTE_TYPE__QUALITY_CONTROL,
                }, {
                    order_by    => 'date',
                    prefetch    => 'operator'
                }
            )->all
    ];

    if ($pack_status->{ready}) { # we have something to pack, tell Invar
        # select packing station if already set - and load list for template
        # TODO: Please remove this section when dcea changes pick/pack/print stuff FELIX
        my $shipment_rs=$schema->resultset('Public::Shipment')->find($shipment_obj->id);
        if($shipment_rs->stickers_enabled){
           # get list of all packing printers in config to populate dropdown (even if one set)
            $handler->{data}->{packing_printers} = $schema->resultset('SystemConfig::ConfigGroup')->search({
                name    => 'PackingPrinterList',
            })->first->config_group_settings();
        }
    }
    my $pack_message =
        $pack_status->{notready}  ? 'not ready to be packed'
      : $pack_status->{on_hold}   ? 'on hold'
      : $pack_status->{cancelled} ? 'cancelled'
      : undef;
    if ($pack_message) {
        my $reason = "The shipment " . $shipment_obj->id . " is $pack_message";
        if ($handler->{data}->{orders_id}) {
            # It's a customer order
            # But we can't really pack this shipment,
            if($pack_status->{notready}) {
                if ( config_var("PRL", "rollout_phase") ) {
                    # Put the tote aside
                    xt_info( $shipment_obj->packing_summary() );
                    xt_warn("$reason; it is awaiting further picks. Please put the tote to the side until all totes have arrived.");
                    return $handler->redirect_to('/Fulfilment/Packing');
                }
            }

            # let's put the items in a packing exception tote
            xt_warn("$reason; please scan its item(s) into new tote(s) and send to the packing exception desk");
            return $handler->redirect_to('/Fulfilment/Packing/PlaceInPEtote?shipment_id='.$shipment_obj->id);
        }
        else {
            # not a customer order, we *don't want* this in packing exception
            xt_warn("$reason; please fix it, then try again");
            return $handler->redirect_to( '/Fulfilment/Packing' );
        }
    }

    if (!$handler->{data}{orders_id}) {
        # Not a customer order so skip QC. Before doing that, perform some tasks
        # that would be done by ProcessPayment (which won't be called).
        $shipment_obj->update({has_packing_started => 1});
        $shipment_obj->shipment_items->mark_containers_out_of_pack_lane;
        return $handler->redirect_to(
            "/Fulfilment/Packing/PackShipment".
            "?shipment_id=".$shipment_obj->id.
            "&packing_printer=".($handler->{data}->{packing_printer} || '')
        );
    }

    # if any Virtual Vouchers don't have a code then you
    # can't proceed, so go back a page and display a message
    if ( $reject_shipment ) {
        xt_warn( $shipment_obj->id.": This Shipment Has Virtual Vouchers without Codes and so you can't proceed. Please Contact Customer Care to Request Virtual Voucher Codes" );
        return $handler->redirect_to( '/Fulfilment/Packing' );
    }

    # if we need to QC the vouchers then redirect to the relevant page
    # but only if we haven't just come from there
    if ( !$handler->{param_of}->{from_pack_qc} ) {
        # delete any 'pack_qc' data that might be in the session
        delete $handler->session->{pack_qc};
        if ( $pack_qc ) {
            return $handler->redirect_to(
                '/Fulfilment/Packing/PackQC?shipment_id='.$shipment_obj->id,
            );
        }
    }

    return $handler->process_template( undef );
}

sub _send_after_class_check {
    my ( $args ) = @_;

    my $schema      = $args->{schema};
    my $msg_factory = $args->{msg_factory};
    my $msg_type    = $args->{msg_type};
    my $operator_id = $args->{operator_id};
    my $shipment_id = $args->{shipment_id};

    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);

    return if $shipment->is_reshipment;
    return if $shipment->pack_status->{pack_complete};

    eval {$schema->txn_do(sub{
        $shipment->create_related('shipment_message_logs', {
            operator_id  => $operator_id,
            message_type => $msg_type,
        });
        $msg_factory->transform_and_send( $msg_type, { shipment_id => $shipment_id } );
    })};
    if ( $@ ) {
        xt_warn("Failed to send $msg_type message for shipment $shipment_id: $@");
    }
}

=head2 _check_allocation_status

Returns boolean value indicating whether the shipment(s) can be packed now.
True unless there are allocations in staged status from Full PRL, or allocations
in any pre-integration status from GOH PRL.

=cut

sub _check_allocation_status {
    my $handler = shift;
    my $associated_container_rs = shift;

    # Start off assuming it's ready
    my $can_be_packed = 1;

    # If totes from Full PRL haven't been inducted yet, they can't be packed
    if ( $associated_container_rs->contains_staged_allocations() ) {
        # TODO: un-hardcode the "Full" bit if we get PRLs that can stage and aren't Full
        # before we rewrite this module entirely.
        xt_warn(sprintf(
            "This shipment is awaiting Full PRL tote(s) [%s] to be inducted",
            join(', ', map {$_->id->as_id} $associated_container_rs->filter_contains_staged_allocations)
        ));
        $can_be_packed = 0;
    }

    if ( $associated_container_rs->contains_pre_integration_allocations() ) {
        # TODO: un-hardcode the "GOH" bit if we get PRLs that can deliver and aren't GOH
        # before we rewrite this module entirely.
        xt_warn("There is a GOH portion of this shipment that is waiting to be processed");
        $can_be_packed = 0;
    }

    return $can_be_packed;
}

1;
