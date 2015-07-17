package XTracker::Order::Fulfilment::PickShipment;
use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Database;
use XTracker::Navigation;
use XTracker::Error;

use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Database::Customer;
use XTracker::Database::Stock         qw( :DEFAULT );
use XTracker::Database::Location      qw( :iws );
use XTracker::Database::StockTransfer qw( get_stock_transfer );
use XTracker::Database::Distribution  qw( check_shipment_item_location check_pick_complete );
use XTracker::Database::Shipment      qw( get_shipment_stock_transfer_id );

use XTracker::Order::Printing::PremierShipmentInfo;
use XTracker::Order::Printing::PremierDeliveryNote;

use XTracker::Image;
use XTracker::Utilities qw( number_in_list );

use XTracker::Constants::FromDB qw( :shipment_status
                                    :shipment_class
                                    :shipment_type
                                    :shipment_item_status
                                    :flow_status );
use XTracker::Config::Local qw( config_var iws_location_name );

use NAP::DC::Barcode::Container;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{SHIPMENT_ITEM_STATUS__SELECTED}=$SHIPMENT_ITEM_STATUS__SELECTED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PICKED}=$SHIPMENT_ITEM_STATUS__PICKED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PACKED}=$SHIPMENT_ITEM_STATUS__PACKED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__DISPATCHED}=$SHIPMENT_ITEM_STATUS__DISPATCHED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION}=$SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION;

    $handler->{data}{ravni_warning} = 1;

    $handler->{dbh}                 = $handler->{schema}->storage->dbh;
    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Picking';
    $handler->{data}{subsubsection} = 'Pick Shipment';
    $handler->{data}{view}          = $handler->{request}->param('view');
    $handler->{data}{shipment_id}   = $handler->{request}->param('shipment_id');
    $handler->{data}{shipment_id} =~ s{\s+}{}g;
    # where we are in the process - first step enter location
    $handler->{data}{process}       = "location";

    my $shipment_id = $handler->{data}{shipment_id};
    my $shipment    = eval{ $handler->{schema}->resultset('Public::Shipment')->find($shipment_id); };
    my $hh_param    = ($handler->{data}{view} && ($handler->{data}{view} eq "HandHeld")) ? '?view=HandHeld' : '';

    if (!$shipment_id) {
        # re-direct to picking overview if no shipment id defined
        xt_warn("No shipment_id provided");
        return $handler->redirect_to( "/Fulfilment/Picking" . $hh_param);
    } elsif ( $shipment_id =~ m{\A\s*(RTVI-\d+)\s*\z}xms ) {
        # redirect RTV shipments to correct page
        ## if an RTV inspection pick request id was entered (prefixed 'RTVI-'), redirect accordingly
        my $rtv_inspection_pick_request_id = $1;
        my $redirect_location = "/RTV/InspectPick?rtv_inspection_pick_request_id=$rtv_inspection_pick_request_id";
        $redirect_location .= '&view=' . lc($handler->{data}{view}) if $handler->{data}{view};
        return $handler->redirect_to( $redirect_location );
    } elsif ( $shipment_id =~ m{\A\s*(RTVS-\d+)\s*\z}xms ) {
        ## if an RTV shipment id was entered (prefixed 'RTVS-'), redirect accordingly
        my $rtv_shipment_id = $1;
        my $redirect_location = "/RTV/PickRTV?rtv_shipment_id=$rtv_shipment_id";
        $redirect_location .= '&view=' . lc($handler->{data}{view}) if $handler->{data}{view};
        return $handler->redirect_to( $redirect_location );
    } elsif ( $handler->iws_rollout_phase > 0) {
        # bounce out of here for non-RTV shipments
        xt_warn("Shipment '$shipment_id' must be picked from IWS");
        return $handler->redirect_to( "/Fulfilment/Picking" . $hh_param);
    } elsif (!$shipment) {
        # re-direct to picking overview if no shipment id defined
        xt_warn("Shipment with id '$shipment_id' not found") if !$shipment;
        return $handler->redirect_to( "/Fulfilment/Picking" . $hh_param);
    }

    # get data needed for page
    _prep_shipment_item_status($handler);
    $handler->{data}{orders_id}         = get_shipment_order_id( $handler->{dbh}, $shipment_id );
    $handler->{data}{shipment}          = get_shipment_info( $handler->{dbh}, $shipment_id );
    $handler->{data}{staff}             = 0;

    # check if customer order
    if ( $handler->{data}{orders_id} ) {
        $handler->{data}{order_info}        = get_order_info( $handler->{dbh}, $handler->{data}{orders_id} );
        $handler->{data}{sales_channel}     = $handler->{data}{order_info}{sales_channel};
        $handler->{data}{sales_channel_id}  = $handler->{data}{order_info}{channel_id};

        my $customer = $handler->{schema}->resultset('Public::Customer')->find($handler->{data}{order_info}{customer_id});

        $handler->{data}{staff} = 1 if ($customer->is_category_staff);
    }
    # must be a stock transfer shipment
    else {
        $handler->{data}{stock_transfer_id} = get_shipment_stock_transfer_id( $handler->{dbh}, $shipment_id );
        $handler->{data}{stock_transfer}    = get_stock_transfer( $handler->{dbh}, $handler->{data}{stock_transfer_id} );
        $handler->{data}{sales_channel}     = $handler->{data}{stock_transfer}{sales_channel};
        $handler->{data}{sales_channel_id}  = $handler->{data}{stock_transfer}{channel_id};
    }

    # set page template and left nav links based on view type
    _set_navigation($handler);
    $handler->{data}{content} = ($hh_param) ? 'ordertracker/fulfilment/handheld_pickshipment.tt' :
                                              'ordertracker/fulfilment/pickshipment.tt';

    if ( $handler->{data}{ready} > 0 &&
         $handler->{data}{picked} == 0 &&
         !$handler->{request}->param('location') ){
        # starting picking. Send a message to XTracker (this is Ravni
        # remember). We may send this message multiple times if the user
        # keeps coming back to this page without actually starting the pick.
        # Oh well - we don't do anything in the the message consumer
        $handler->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::WMS::PickingCommenced',
            $shipment,
        );
    }

    # process location/sku/container entered by user
    _process_location($handler);
    _process_sku($handler);
    _process_container($handler, $shipment);


    # check if we need to redirect to item count
    if ($handler->{data}{redirect_url}){
        return $handler->redirect_to( $handler->{data}{redirect_url} );
    }


    return $handler->process_template();
}

sub _prep_shipment_item_status {
    my ($handler) = @_;

    $handler->{data}{shipment_item_info} = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );

    # counters to work out where we are in the picking process
    $handler->{data}{ready}     = 0;
    $handler->{data}{notready}  = 0;
    $handler->{data}{picked}    = 0;

    # loop over items in shipment
    # work out what stage it's at
    # and get images for product
    foreach my $ship_item_id ( keys %{ $handler->{data}{shipment_item_info} } ) {
        my $item_info   = $handler->{data}{shipment_item_info}{$ship_item_id};

        # find out if the item is a Virtual Voucher
        if ( $item_info->{voucher} && !$item_info->{is_physical} ) {
            # if it is delete it from the list of items that will
            # be displayed in the picking pages
            delete $handler->{data}{shipment_item_info}{$ship_item_id};
            next;
        }

        my $status_id   = $item_info->{shipment_item_status_id};
        if ( $status_id == $SHIPMENT_ITEM_STATUS__NEW ){
            $handler->{data}{notready}++;
        } elsif ( $status_id == $SHIPMENT_ITEM_STATUS__SELECTED ){
            $handler->{data}{ready}++;
        } elsif ( number_in_list($status_id,
                               $SHIPMENT_ITEM_STATUS__PICKED,
                               $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                               $SHIPMENT_ITEM_STATUS__PACKED,
                               $SHIPMENT_ITEM_STATUS__DISPATCHED,
                               $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                               $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                               $SHIPMENT_ITEM_STATUS__RETURNED,
                           ) ) {
            $handler->{data}{picked}++;
        }
        $handler->{data}{shipment_item_info}{$ship_item_id}{image} = get_images({
            product_id => $item_info->{product_id},
            live => 1,
            schema => $handler->schema,
        });
        $handler->{data}{shipment_item_info}{$ship_item_id}{staff} = 1;
    }
}

sub _process_location {
    my ($handler) = @_;

    # check that they submitted the form
    return unless defined $handler->{request}->param('location');

    # clean location entered by user
    $handler->{data}{location} = $handler->{request}->param('location');
    $handler->{data}{location} =~ s/\s+//g;

    if ($handler->iws_rollout_phase > 0) {
        if (matches_iws_location($handler->{data}{location})) {
            return xt_warn("Location '".iws_location_name()."' may not be picked from\n");
        }
    }

    # get location info for location
    my $location = eval {
        $handler->{schema}->resultset('Public::Location')->get_location({
                                                       location => $handler->{data}{location},
                                                    });
    };

    # validate location
    if (!$location){
        return xt_warn("The location entered could not be found.");
    } elsif (!$location->allows_status($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS)){
        # not a main stock location entered, switch process back and give message for user
        return xt_warn("The location entered was not a valid main stock location.")
    }

    # validates OK. set some template data
    $handler->{data}{location_id} = $location->id;
    $handler->{data}{process}   = "sku";
}

sub _process_sku {
    my ($handler) = @_;

    # check that we're at this stage and location validate
    return unless defined $handler->{request}->param('sku');
    return unless $handler->{data}{process} eq "sku";

    # clean location entered by user
    $handler->{data}{sku} = $handler->{request}->param('sku');
    $handler->{data}{sku} =~ s/\s+//g;

    return xt_warn("Invalid SKU Entered") if ($handler->{data}{sku} !~ m/\d+-\d+/);

    # check sku is in shipment
    $handler->{data}{shipment_item_id} = get_shipment_item_by_sku($handler->{dbh}, $handler->{data}{shipment_id}, $handler->{data}{sku});
    return xt_warn("The sku entered ($handler->{data}{sku}) is not part of this shipment.")
        unless $handler->{data}{shipment_item_id};

    # check sku as correct status to pick
    $handler->{data}{process}   = "location"; # if there's any errors we'll push back to location step
    my $status = get_shipment_item_status($handler->{dbh}, $handler->{data}{shipment_item_id});
    return xt_warn("The item entered is not ready to be picked.")
        if ( $status == $SHIPMENT_ITEM_STATUS__NEW );
    return xt_warn("The item entered has been cancelled, please place the item back in stock.")
        if ( $status == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING ||
             $status == $SHIPMENT_ITEM_STATUS__CANCELLED );
    return xt_warn("The item entered has already been picked.")
        if ( $status != $SHIPMENT_ITEM_STATUS__SELECTED );

    # check location entered has stock to be picked
    # return value of 'check_shipment_item_location': 1 means "not there", 2 and 3 mean "there is some"
    return xt_warn("The SKU entered does not exist in the location entered, please contact Stock Control.")
        if check_shipment_item_location( $handler->{dbh}, $handler->{data}{shipment_item_id}, $handler->{data}{location_id} ) < 2;

    # validates OK, set template data
    $handler->{data}{process}   = "container";
}

sub _process_container {
    my ($handler, $shipment) = @_;

    # check that we're at this stage and that location && sku validate
    return unless defined $handler->{request}->param('container_id');
    return unless $handler->{data}{process} eq "container";

    my $shipment_item = $handler->{schema}->resultset('Public::ShipmentItem')->find($handler->{data}{shipment_item_id});
    die "Shipment item $handler->{data}{shipment_item_id} not found" unless $shipment_item;

    # make sure that provided "container ID" is valid
    my $err;
    try {
        $handler->{data}{container_id} = NAP::DC::Barcode::Container->new_from_barcode(
            $handler->{request}->param('container_id')
        );
        $err = 0;
    } catch {
        xt_warn($_);
        $err = 1;
    };
    return if $err;

    eval { $shipment_item->validate_pick_into($handler->{data}{container_id}); };

    if (my $error = $@) {
        return xt_warn($error);
    }

    eval { $handler->{schema}->txn_do( sub{
        # if we're here then we've done all our validation
        _pick_shipment_item( $handler , $shipment_item);
    }); };
    if (my $e = $@) {
        # db updates not successful
        xt_warn("There was a problem trying to pick this item, please try again : " . $e);
        return;
    }

    # All processed and picked OK. YAY

    # Shipment item data data will have changed so re-fetch it
    _prep_shipment_item_status($handler);
    # reset process so we can pick the next item
    $handler->{data}{process} = "location";
}


sub _pick_shipment_item {
    my ($handler, $shipment_item) = @_;

    # if it's a stock transfer shipment allocate stock to "Transfer Pending" location
    # this is a sample transfer NOT channel transfer.
    my $channel_id;
    my $to_param;
    if ($handler->{data}{shipment}{shipment_class_id} == $SHIPMENT_CLASS__TRANSFER_SHIPMENT){
        $channel_id = $handler->{data}{stock_transfer}->{channel_id};
        $to_param   = { location  => $handler->{schema}->resultset('Public::Location')->find({location => 'Transfer Pending'}),
                        status    => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS, }
    } else {
        $channel_id = $handler->{data}{order_info}->{channel_id};
    }

    # pick item - the status change is logged
    $shipment_item->pick_into($handler->{data}{container_id},
                              $handler->{data}{operator_id},
                              {dont_validate => 1}, # already validated
                             );

    # update quantity table
    my $variant_id = $handler->{data}{shipment_item_info}{ $handler->{data}{shipment_item_id} }{variant_id};
    $handler->{schema}->resultset('Public::Quantity')->move_stock({
        variant         => $variant_id,
        channel         => $channel_id,
        quantity        => 1,
        from            => {
            location        => $handler->{data}{location_id},
            status          => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        },
        to              => $to_param,
        keep_if_zero    => 1, # don't delete row if quantity goes to zero. Need Final Pick confirmation
        log_location_as => $handler->{data}{operator_id},
    });

    # check if pick complete and print out stuff for Premier orders
    # UPDATE: DC1 no longer requires this paperwork
    if ( config_var('Print_Document', 'requires_premier_nonpacking_printouts') ) {
        my $complete = check_pick_complete($handler->{dbh}, $handler->{data}{shipment_id});
        if ($complete == 1 &&
            $handler->{data}{shipment}{shipment_type_id} == $SHIPMENT_TYPE__PREMIER &&
            $handler->{data}{shipment}{shipment_class_id} != $SHIPMENT_CLASS__TRANSFER_SHIPMENT){
            generate_premier_info($handler->{dbh}, $handler->{data}{shipment_id}, "Premier Shipping", 1);
            generate_premier_delivery_note($handler->{dbh}, $handler->{data}{shipment_id}, "Premier Shipping", 1);
        }
    }

    # everything finished with pick
    # check if stock counting is switched on
    # AND stock count is needed on the item
    if (check_stock_count_variant($handler->{dbh}, $variant_id, $handler->{data}{location}, get_stock_count_setting($handler->{dbh}, "picking") )){
        $handler->{data}{redirect_url} = '/Fulfilment/Picking/CountVariant?redirect_id='.$handler->{data}{shipment_id}.'&redirect_type=Pick&variant_id='.$variant_id.'&location='.$handler->{data}{location};
        $handler->{data}{redirect_url} .= "&view=HandHeld"
            if $handler->{data}{handheld} == 1;
    }

    if ($shipment_item->shipment->is_pick_complete){
        # if this was the last item to pick then we need to send a 'shipment_ready' message to XTracker (this is Ravni remember)
        $handler->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::WMS::ShipmentReady',
            $shipment_item->shipment,
        );
    }

    return;
}

sub _set_navigation {
    my ($handler) = @_;
    my $hh_param    = ($handler->{data}{view} && ($handler->{data}{view} eq "HandHeld")) ? 'view=HandHeld' : '';
    # back to picking
    push @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "/Fulfilment/Picking" . ($hh_param ? "?$hh_param" : '') };

    # incomplete pick link for left nav, only for non-sample shipments
    if (! number_in_list($handler->{data}{shipment}{shipment_class_id},
                         $SHIPMENT_CLASS__TRANSFER_SHIPMENT,
                         $SHIPMENT_CLASS__SAMPLE
                     ) ) {
        push @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Incomplete Pick', 'url' => "/Fulfilment/Picking/IncompletePick?shipment_id=$handler->{data}{shipment_id}" . ($hh_param ? "&$hh_param" : '')};
    }
}

