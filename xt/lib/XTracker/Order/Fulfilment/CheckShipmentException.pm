package XTracker::Order::Fulfilment::CheckShipmentException;
use NAP::policy "tt";

use Digest::MD5                         qw/md5_hex/;

use NAP::DC::Barcode::Container;
use XTracker::Handler;
use XTracker::Error;
use XTracker::Image;
use XTracker::Database qw( get_schema_using_dbh get_database_handle);
use XTracker::Database::Shipment        qw( :DEFAULT :carrier_automation );
use XTracker::Database::Address;
use XTracker::Database::Product;
use XTracker::Database::StockTransfer   qw( get_stock_transfer );
use XTracker::Database::Order;
use XTracker::Database::Container       qw( :validation );

use XTracker::Comms::FCP                qw( update_web_stock_level );
use XTracker::Database::Logging qw( log_stock );

use XTracker::Utilities                 qw( parse_url url_encode number_in_list );
use XTracker::Constants::FromDB         qw(
    :container_status
    :note_type
    :packing_exception_action
    :pws_action
    :shipment_item_status
    :shipment_status
    :shipment_type
    :stock_action
);
use XTracker::Navigation                qw( build_packing_nav );
use XTracker::DBEncode                  qw( encode_it );


### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {
    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    # Check whatever they scanned is sane
    $handler->{param_of}{shipment_id} =~ s/\s//g;
    my $scan_string = $handler->{param_of}{shipment_id};
    if ( ! $scan_string ) {
        xt_warn("Please scan either a container ID or a shipment ID");
        return $handler->redirect_to( '/Fulfilment/PackingException' );
    }

    # Assign it
    my $shipment_id = ($scan_string =~ m/^\d+$/ ? $scan_string : undef );
    my $container_id = eval {
        # Scanned value, parse as full barcode
        NAP::DC::Barcode::Container->new_from_barcode($scan_string);
    } // undef;

    # Complain if they scanned something that isn't obviously either a shipment
    # or a container
    my $container_or_shipment_id = $container_id || $shipment_id;
    unless ( $container_or_shipment_id ) {
        xt_warn("Please scan either a container ID or a shipment ID");
        return $handler->redirect_to( '/Fulfilment/PackingException' );
    }

    # If it was a container, try and find it.
    if ( $container_id ) {
        my $container = $handler->{schema}->resultset('Public::Container')->find(
            $container_id
        );

        if ( ! $container ) {
            xt_warn("Couldn't find any information on container $container_id");
            return $handler->redirect_to( "/Fulfilment/PackingException" );
        }

        # for some reason, repair the tote's status here
        # instead of in cancel shipment, where it should be repaired...
        if ( $container->is_in_commissioner && $container->are_all_items_cancel_pending ) {
            $container->remove_from_commissioner;
            $container->update({status_id => $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS});
        }

        # If it's a superfluous item container then redirect to view tote
        # (In real life, because people suck, it may have orphan items in it even if the tote
        # is no longer in 'superfluous item' status. This happens when things are picked into
        # the tote via shipment_ready message when XT thinks the tote is still in PE with
        # superfluous items. Hence checking both conditions)
        if ( $container->status_id == $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS ||
             $container->orphan_items->count ) {
            if ($container_id->is_type("pigeon_hole")) {
                xt_success("Ensure item has been returned to pigeon hole $container_id");
            }
            return $handler->redirect_to(
                "/Fulfilment/PackingException/ViewContainer?container_id=" .
                $container_id
            );
        }
    }

    # Drop back in to the old logic
    my @shipment_ids = get_shipment_ids_from_id_or_container(
        $handler->{dbh},
        $container_or_shipment_id,
    );
    my @shipments = map { # TODO: search() with -in @shipment_ids, hello?
        $handler->{schema}->resultset('Public::Shipment')->find($_)
    } @shipment_ids;

    my @cancelled_shipments = grep {
        $_->shipment_status_id == $SHIPMENT_STATUS__CANCELLED
    } @shipments;

    my @failed_shipments = grep {
        $_->is_at_packing_exception
    } @shipments;

    if (@failed_shipments > 1) {
        # this should never happen!
        # we should only have 1 shipment per PE tote
        # let's pretend we know what we're doing
        splice @failed_shipments, 1;
    }

    # DCEA-1658
    # If all shipments in here are cancelled, but it contains packable items, something has gone wrong
    if (@cancelled_shipments && ($#cancelled_shipments == $#shipments) && $container_id) {
        my $container_rs = $handler->{schema}->resultset('Public::Container')->search({
            'id' => $container_id
        });
        if ($container_rs && $container_rs->contains_packable) {
            xt_warn("Container $container_id has shipment items from shipment ".join(',',map {$_->id} @cancelled_shipments)." in an incorrect state, please report this issue to service desk.");
            return $handler->redirect_to( "/Fulfilment/PackingException" );
        }
    }

    if (@failed_shipments) {
        if (my $r = _check_change($handler,$failed_shipments[0])) { return $r }
        if ( $handler->{request}->param('missing') ) {
            _missing_item($handler,$failed_shipments[0]);
        } elsif ( $handler->{request}->param('item_ok')) {
            _fix_item($handler,$failed_shipments[0]);
            return $handler->redirect_to( delete $handler->{data}->{scan_item_back_into_tote} )
                if $handler->{data}->{scan_item_back_into_tote};
        } elsif ($handler->{request}->param('extra_item_ok')){
            _fix_extra_item($handler,$failed_shipments[0]);
        }
        return _show_failed_shipment($handler,$failed_shipments[0]);
    }
    elsif (@shipments == 1 &&
               ( $handler->iws_rollout_phase ?
                     $shipments[0]->non_canceled_items->are_all_selected :  $shipments[0]->non_canceled_items->are_all_new) ){
        if (my $r = _check_change($handler,$shipments[0])) { return $r }

        # let them continue and say "all items have been checked" if
        # all items are awaiting replacements
        return _show_failed_shipment($handler,$shipments[0]);
    }
    else {
        my @known_shipments = grep {
            $_->is_on_hold || $_->shipment_status_id == $SHIPMENT_STATUS__PROCESSING
        } @shipments;

        my @unknown_shipments = grep {
            ! ( $_->is_on_hold ||
                $_->shipment_status_id == $SHIPMENT_STATUS__PROCESSING ||
                $_->shipment_status_id == $SHIPMENT_STATUS__CANCELLED )
        } @shipments;

        if (@known_shipments) {
            my $known_ships = join (', ',map { $_->id } @known_shipments);

            if (@known_shipments == 1) {
                xt_success("Shipment $known_ships is not in packing exception status");
            }
            else {
                xt_success("Shipments $known_ships are not in packing exception status");
            }
        }

        if (@cancelled_shipments) {
            my $cancelled_ships = join (', ',map { $_->id } @cancelled_shipments);

            if (@cancelled_shipments == 1) {
                xt_success("Cancelled shipment $cancelled_ships has now been dealt with");
            }
            else {
                xt_success("Cancelled shipments $cancelled_ships have now been dealt with");
            }
        }

        if (@unknown_shipments) {
            my $unknown_ships = join (', ',map { $_->id } @unknown_shipments);

            if (@unknown_shipments == 1) {
                xt_warn("Shipment ID $unknown_ships is not recognized");
            }
            else {
                xt_warn("Shipment IDs $unknown_ships are not recognized");
            }
        }

        if (!@known_shipments && !@unknown_shipments && !@cancelled_shipments) {
            xt_warn("Couldn't find any information on container or shipment $scan_string");
        }

        return $handler->redirect_to( '/Fulfilment/PackingException' );
    }
}

# Check if shipment signature match e.g. nothing has changed since we
# loaded the page.
sub _check_change {
    my ($handler,$shipment)=@_;

    return unless $shipment;

    my $shipment_state_signature = md5_hex( encode_it($shipment->state_signature) );
    if ($handler->{param_of}{shipment_state_signature}
            && ($shipment_state_signature ne $handler->{param_of}{shipment_state_signature})
        ) {
        xt_warn(sprintf("Shipment %s has changed since you started working on it. Your last action has been ignored. Carry on.",$shipment->id));
        return $handler->redirect_to( '/Fulfilment/Packing/CheckShipmentException?shipment_id=' . $shipment->id );
    }
}

sub _show_failed_shipment {
    my ($handler,$shipment) = @_;

    my $dbh         = $handler->{dbh};
    my $channel_id;

    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Packing';
    $handler->{data}{subsubsection} = 'Check Shipment Exception';
    $handler->{data}{content}       = 'ordertracker/fulfilment/checkshipmentexception.tt';

    # This flag shows us a bunch of fields that are in the packing_common.tt
    # template that we normally want to hide
    $handler->{data}{extended_view} = 1;

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, {
        'title' => 'Back',
        'url' => '/Fulfilment/PackingException'
    } );

    # flag the template this is a different action that the original
    $handler->{data}{packingexception} = 1;

    # get shipment info
    $handler->{data}{shipment} = $shipment;
    my $shipment_id = $shipment->id;

    # id of the shipment we're packing
    # (* don't pass on the {param_of}{shipment_id}, because it can be a container ID as well *)
    $handler->{data}{shipment_id}   = $shipment_id;

    # Check if we're still at Packing Exception
#    unless ($shipment->is_at_packing_exception || $shipment->non_canceled_items->are_all_new) {
    unless ($shipment->is_at_packing_exception ||
                ( $handler->iws_rollout_phase ?
                      $shipment->non_canceled_items->are_all_selected : $shipment->non_canceled_items->are_all_new) ) {
        xt_warn("The shipment $shipment_id has already been fixed") if $shipment->non_canceled_items->all;
        return $handler->redirect_to('/Fulfilment/PackingException');
    }

    $handler->{data}{shipment_info}         = get_shipment_info( $dbh, $shipment_id );
    $handler->{data}{shipment_address}      = get_address_info( $dbh, $handler->{data}{shipment_info}{shipment_address_id} );
    $handler->{data}{orders_id}             = get_shipment_order_id( $dbh, $shipment_id );
    my $item_info = $handler->{data}{shipment_item_info} = get_shipment_item_info( $dbh, $shipment_id );
    $handler->{data}{shipment_extra_items}  = $shipment->picking_print_docs_info();
    my $channel_ob = $shipment->get_channel;
    $handler->{data}{channel_info} = {%{$channel_ob->data_as_hash},
                                      business => $channel_ob->business->data_as_hash};

    # check if customer order
    if ( $handler->{data}{orders_id} ) {
        $handler->{data}{order_info}        = get_order_info( $dbh, $handler->{data}{orders_id} );
        $handler->{data}{sales_channel}     = $handler->{data}{order_info}{sales_channel};
        $channel_id = $handler->{data}{order_info}{channel_id};
    }
    # must be a stock transfer shipment
    else {
        $handler->{data}{stock_transfer_id} = get_shipment_stock_transfer_id( $dbh, $shipment_id );
        $handler->{data}{stock_transfer}    = get_stock_transfer( $dbh, $handler->{data}{stock_transfer_id} );
        $handler->{data}{sales_channel}     = $handler->{data}{stock_transfer}{sales_channel};
        $channel_id = $handler->{data}{stock_transfer}{channel_id};
    }

    # Retrieve any notes to do with packing exceptions
    $handler->{'data'}->{'shipment_packing_exception_notes'} = [
        $shipment->search_related(
            'shipment_notes',
            {
                note_type_id => $NOTE_TYPE__QUALITY_CONTROL,
            }, {
                order_by    => 'date',
                prefetch    => 'operator'
            }
        )->all
    ];

    $handler->{data}{is_packing_exception_completed} = $shipment->is_packing_exception_completed;

    # work out if shipment ready to be packed
    $handler->{data}{pack_status}{ready}    = 0;
    $handler->{data}{pack_status}{notready} = 0;
    $handler->{data}{pack_status}{packed}   = 0;

    foreach my $ship_item_id ( keys %{ $item_info } ) {
        # find out if the item is a Virtual Voucher
        if ( $item_info->{$ship_item_id}{voucher} && !$item_info->{$ship_item_id}{is_physical} ) {
            # if it is delete it from the list of items that will
            # be displayed in the page
            delete $item_info->{$ship_item_id};
            next;
        }

        $item_info->{$ship_item_id}{image} = get_images({
            product_id => $item_info->{$ship_item_id}{product_id},
            live => 1,
            schema => $handler->schema,
        });

        $item_info->{$ship_item_id}{product} = $handler->schema->resultset('Public::Product')->find($item_info->{$ship_item_id}{product_id});

        $item_info->{$ship_item_id}{live} = $handler->schema->resultset('Public::ProductChannel')->pids_live_on_channel($channel_ob->id, [$item_info->{$ship_item_id}{product_id}]);

        $item_info->{$ship_item_id}{ship_att} =
            get_product_shipping_attributes($handler->{dbh}, $item_info->{$ship_item_id}{product_id} );

        # PEC: I don't think we care about this but to see the items in exception.
        # But we are ready regardless, we just want to show the shipment items.
        $handler->{data}{pack_status}{ready}++;

    }

    $shipment->discard_changes;
    $handler->{data}{shipment_state_signature} = md5_hex( encode_it($shipment->state_signature) );
    return $handler->process_template( undef );
}

sub _missing_item {
    my ($handler,$shipment) = @_;

    # sanitize input
    $handler->{param_of}{shipment_item_id} =~ s{\s+}{}g;

    if (!$handler->{param_of}{shipment_item_id}) {
        xt_warn("No shipment item was selected...");
        return;
    }

    # Make sure it exists?
    my $missing_si = $shipment->find_related( 'shipment_items', {
        id => $handler->{param_of}{shipment_item_id},
    });

    # PEC TODO, Big kaboom
    die "Can't find shipment item $handler->{param_of}{shipment_item_id}\n"
        unless $missing_si;

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;
    eval { $schema->txn_do(sub{
        my $is_item_cancelled;

        # Update status to NEW(phase 0) or SELECTED(all other phases) and log
        my $si_status;
        if ( $missing_si->is_cancel_pending ) {
            $si_status = $SHIPMENT_ITEM_STATUS__CANCELLED;
            $is_item_cancelled = 1;
        } else {
            $si_status = $handler->iws_rollout_phase
                       ? $SHIPMENT_ITEM_STATUS__SELECTED
                       : $SHIPMENT_ITEM_STATUS__NEW;
        }
        $missing_si->update_status(
            $si_status, $handler->operator_id, $PACKING_EXCEPTION_ACTION__MISSING
        );

        my $variant = $missing_si->get_true_variant;

        my $msg_params = {
            to    => { place => 'lost', stock_status => 'main' },
            items => [{
                sku      => $variant->sku,
                quantity => 1,
                client   => $variant->get_client()->get_client_code(),
            },],
        };

        # The missing whilst travelling from the packer bench to packing exception has a container_id
        if (defined $missing_si->container_id) {
            $msg_params->{from}->{container_id} = $missing_si->container_id;
            # Release it from the container
            $missing_si->unpick;
        }

        my $channel = $shipment->get_channel;

        log_stock(
            $dbh,
            {
                variant_id  => $variant->id,
                action      => $STOCK_ACTION__MANUAL_ADJUSTMENT,
                quantity    => -1,
                operator_id => $handler->operator_id,
                notes       => 'missing item at Packing Exception for shipment '.$shipment->id,
                channel_id  => $channel->id,
            }
        );

        # Cancelled Items just need an item moved...
        if ( $is_item_cancelled ) {
            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::WMS::ItemMoved',{
                shipment_id => $shipment->id,
                %$msg_params,
            });
            xt_success( sprintf( 'Cancelled item %s has been marked as missing', $variant->sku() ) );
        }
        # Decrement web stock to match XTracker free stock
        # don't care at this point whether there is actually any
        # free stock. We'll catch that later in the process
        else {
            my $stock_manager = XTracker::WebContent::StockManagement->new_stock_manager({
                schema      => $schema,
                channel_id  => $channel->id,
            });

            $stock_manager->stock_update(
                quantity_change => -1,
                variant_id      => $variant->id,
                pws_action_id   => $PWS_ACTION__MANUAL_ADJUSTMENT,
                operator_id     => $handler->operator_id,
                notes           => 'missing item at Packing Exception for shipment '
                    . $shipment->id,
            );

            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::WMS::ItemMoved',{
                shipment_id => $shipment->id,
                %$msg_params,
            });

            $stock_manager->commit();
            xt_success( sprintf( 'sku %s has been marked as missing and is awaiting replacement.', $variant->sku() ) );
        }

    });};
    if (my $e = $@) {
        xt_warn($e);
    }
}

sub _fix_item {
    my ($handler,$shipment) = @_;

    # sanitize input
    $handler->{param_of}{shipment_item_id} =~ s{\s+}{}g;
    return xt_warn("No shipment item was selected...")
        if (!$handler->{param_of}{shipment_item_id} || $handler->{param_of}{shipment_item_id} eq "");

    # Make sure it exists?
    my $si = $shipment->search_related(
        'shipment_items',
        {
            id => $handler->{param_of}{shipment_item_id},
        })->single;
    return xt_warn("Cannot find shipment item '$handler->{param_of}{shipment_item_id}' in order to fix it fix. ") unless $si;

    if (
        (
            $si->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ||
            $si->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
        ) && defined $si->container_id){
        # if shipment item is in packing exception state and is in a tote, we can fix it by setting status to 'picked'
        $si->qc_failure_reason(undef);
        $si->update_status( $SHIPMENT_ITEM_STATUS__PICKED, $handler->operator_id )
            if $si->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION;
        my $message = sprintf("shipment item %s has been marked as non-faulty. ",$si->get_sku);
        if ($si->container->is_pigeonhole) {
            $message .= sprintf("Return item to pigeon hole %s before continuing.", $si->container_id);
        }
        xt_success($message);
    } elsif (
        (
            $si->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ||
            $si->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
        ) && !defined $si->container_id){
        # if shipment item is in packing exception state and is NOT in a tote, we need to scan it into a tote
        # Deal with the redirect back in the main handle function
        $handler->{data}->{scan_item_back_into_tote} = '/Fulfilment/PackingException/ScanItemIntoTote' .
                                                       '?shipment_id='. $shipment->id . '&shipment_item_id=' . $si->id;
    } else {
        xt_warn("shipment item '$handler->{param_of}{shipment_item_id}' is not faulty in the first place. Can't fix it")
    }
}

sub _fix_extra_item {
    my ($handler,$shipment) = @_;

    my $sei_type = $handler->{param_of}{shipment_extra_item_type};
    return xt_warn("No Additional shipment item was selected")
        unless $sei_type;

    # try and delete the shipment_extra_item record.
    eval {
        my $deleted = $shipment->qc_fix_shipment_extra_item($sei_type);
        xt_success("Shipment extra item '$sei_type' marked as fixed") if $deleted;
    };
    if (my $e = $@){
        xt_warn("Failed to QC pass extra shipment item $sei_type : $e");
    }
}

1;
