package XTracker::Order::Fulfilment::PackShipment;
use NAP::policy "tt";

use NAP::DC::Barcode::Container;
use NAP::DC::Barcode::Container::Tote;

use XTracker::Image;
use XTracker::Handler;
use XTracker::Database::Order;
use XTracker::Database::Shipment        qw( :DEFAULT :carrier_automation );
use XTracker::Database::Product         qw( get_product_channel_info );
use XTracker::Database::Address;
use XTracker::Database::Invoice;
use XTracker::Database::Logging         qw( log_stock );
use XTracker::Database::StockTransfer   qw( get_stock_transfer );
use XTracker::Database::Distribution    qw( AWBs_are_present );
use XTracker::Database::Container qw( :validation );

use XTracker::DHL::AWB                  qw( log_dhl_waybill );
use XTracker::Promotion::Marketing;

use XTracker::Constants::FromDB qw(
    :department
    :note_type
    :shipment_class
    :shipment_item_status
    :shipment_status
    :stock_action
);

use XTracker::Config::Local             qw( config_var manifest_level manifest_countries get_packing_station_printers get_shipping_printers );
use XTracker::Navigation                qw( build_packing_nav );

use XTracker::Order::Printing::ShipmentDocuments        qw( generate_shipment_paperwork
                                                            print_shipment_documents
                                                          );
use XTracker::Order::Printing::PremierShipmentDocuments;
use XTracker::Order::Printing::ShippingInputForm;
use XTracker::Order::Printing::OutwardProforma;
use XTracker::Order::Printing::AddressCard;

use XTracker::Utilities qw( url_encode number_in_list strip_txn_do );
use XTracker::Logfile qw( xt_logger );

use XTracker::Error;

use XT::Data::PRL::Conveyor::Route::ToDispatch;

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Packing';
    $handler->{data}{subsubsection} = 'Pack Shipment';
    $handler->{data}{content}       = 'ordertracker/fulfilment/packshipment.tt';

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "/Fulfilment/Packing" } );
    # check for 'Set Packing Station' link
    my $sidenav = build_packing_nav( $handler->{schema} );
    if ( $sidenav ) {
        push(@{ $handler->{data}{sidenav}[0]{'None'} }, $sidenav );
    }

    # restrict length of airway bill field - default to 10 digits
    $handler->{data}{waybill_length} = 10;

    # config manifest settings
    $handler->{data}{manifest_level}        = manifest_level();
    $handler->{data}{manifest_countries}    = manifest_countries();

    # shipment id from url or form submit
    $handler->{data}{shipment_id} = $handler->{param_of}{shipment_id} // '';
    $handler->{data}{shipment_id} =~ s{\s+}{}g;

    # no shipment id? then we shouldn't be here - redirect back to Packing screen
    if ( !$handler->{data}{shipment_id} ) {
        return $handler->redirect_to( "/Fulfilment/Packing" );
    }

    # get the dbic object
    my $shipment = $handler->{schema}->resultset('Public::Shipment')->find($handler->{data}{shipment_id});
    $handler->{data}{shipment} = $shipment if $shipment;

    # shipment not found? redirect back to Packing screen
    if (!$handler->{data}{shipment}){
        xt_warn("Shipment id '$handler->{data}{shipment_id}' not found");
        return $handler->redirect_to( "/Fulfilment/Packing" );
    }

    # STICKERS!
    if(
        $shipment->stickers_enabled &&
        $handler->{param_of}{packing_printer} &&
        # Either pre-phase 2, or we haven't already printed any
        ( $handler->iws_rollout_phase < 2 || (! $shipment->stickers_printed ) )
    ){
        my $prefs = $handler->{schema}->resultset('Public::OperatorPreference')->update_or_create({
            operator_id                => $handler->operator_id(),
            packing_printer            => $handler->{param_of}{packing_printer},
        });
        my $copies = $shipment->shipment_items->count();
        $shipment->print_sticker($prefs->packing_printer(),$copies);
    }

    # get the basic shipment info we need
    $handler->{data}{container_ids} = $handler->{param_of}{container_ids} || [
        $handler->{data}{shipment}->packable_container_ids
    ];
    # easier to deal with later if we make sure a single container_ids param
    # still results in an arrayref
    if (ref $handler->{data}{container_ids} ne 'ARRAY') {
        $handler->{data}{container_ids} = [$handler->{data}{container_ids}];
    }
    # transform to Barcode::Container objects and validate
    my $err;
    try {
        $handler->{data}{container_ids} = [
            # May be ids from db, or from an id rendered into a
            # template rather than scanned
            map { NAP::DC::Barcode::Container->new_from_id($_) }
            @{$handler->{data}{container_ids}}
        ];
        $err=0;
    }
    catch {
        $err=1;
        xt_warn($_);
    };
    return $handler->process_template if $err;

    # Sometimes we only want the totes (not pigeon holes or anything else)
    my @tote_ids =
        grep { $_->isa("NAP::DC::Barcode::Container::Tote") }
        @{$handler->{data}{container_ids}};
    # Is this even used anywhere? I can't find anywhere...
    $handler->{data}{tote_ids} = \@tote_ids;

    $handler->{data}{shipment_info}         = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
    $handler->{data}{shipment_boxes}        = get_shipment_boxes( $handler->{dbh}, $handler->{data}{shipment_id} );
    $handler->{data}{shipment_item_info}    = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );
    $handler->{data}{shipment_address}      = get_address_info( $handler->{dbh}, $handler->{data}{shipment_info}{shipment_address_id} );
    $handler->{data}{shipping_country}      = get_country_info( $handler->{dbh}, $handler->{data}{shipment_address}{country} );
    $handler->{data}{returnable_status}     = $shipment->get_shipment_returnable_status;

    # Retrieve any notes to do with packing exceptions
    $handler->{'data'}->{'shipment_packing_exception_notes'} = [
        $handler->{'schema'}->resultset('Public::ShipmentNote')->search(
                {
                    shipment_id  => $handler->{data}{shipment_id},
                    note_type_id => $NOTE_TYPE__QUALITY_CONTROL,
                }, {
                    order_by    => 'date',
                    prefetch    => 'operator'
                }
            )->all
    ];

    # check if customer order
    if ( $handler->{data}{shipment_info}{orders_id} ) {
        $handler->{data}{order_info}        = get_order_info( $handler->{dbh}, $handler->{data}{shipment_info}{orders_id} );
        $handler->{data}{promotions}        = get_order_promotions( $handler->{dbh}, $handler->{data}{shipment_info}{orders_id} );
        $handler->{data}{sales_channel}     = $handler->{data}{order_info}{sales_channel};
        $handler->{data}{sales_channel_id}  = $handler->{data}{order_info}{channel_id};

        # CANDO-880 : Marketing promotion- In the Box
        # Apply marketing promotions to order, if shipment class is not exchange
        if( $shipment->can_have_in_the_box_promotions ) {
            eval {
                my $order_obj   = $handler->schema->resultset('Public::Orders')->find( $handler->{data}{shipment_info}{orders_id} );

                my $mp_obj = XTracker::Promotion::Marketing->new({
                    schema  => $handler->{schema},
                    order   => $order_obj,
                });
                $mp_obj->apply_to_order();

                # get promotions messages
                $handler->{data}{marketing_promotions} = $order_obj->get_all_marketing_promotions();
            };
            if ( my $err = $@ ) {
                # this failing is not worth stopping Packing
                # for but should log the failure anyway
                xt_logger->error( "Couldn't Process In The Box Promotion: " . $err );
            }
        }
    }
    # must be a stock transfer shipment
    else {
        $handler->{data}{stock_transfer_id} = get_shipment_stock_transfer_id( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{stock_transfer}    = get_stock_transfer( $handler->{dbh}, $handler->{data}{stock_transfer_id} );
        $handler->{data}{sales_channel}     = $handler->{data}{stock_transfer}{sales_channel};
        $handler->{data}{sales_channel_id}  = $handler->{data}{stock_transfer}{channel_id};
    }

    # if packing station required but not set or packing station no longer active, redirect to
    # packing overview with appropriate error message
    my $ps_check    = check_packing_station( $handler, $handler->{data}{shipment_id}, $handler->{data}{sales_channel_id} );
    if ( !$ps_check->{ok} ) {
        # go back to Fulfilment/Packing
        xt_warn($ps_check->{fail_msg});
        return $handler->redirect_to( '/Fulfilment/Packing' );
    }

    # check carrier on shipment for AWB length
    if ( $handler->{data}{shipment_info}{carrier} eq 'UPS') {
        $handler->{data}{waybill_length} = 18;
    }

    # set default page view to item pack
    $handler->{data}{process} = 'sku';

    # switch to box view
    if ( $handler->{param_of}{switch_box} ) {
        $handler->{data}{process} = 'box';
    }

    # switch to item pack view
    if ( $handler->{param_of}{switch_sku} ) {
        $handler->{data}{process} = 'sku';
    }


    # process form post
    my $is_packing_complete = 0;

    # pack item form submitted
    if ( $handler->{param_of}{pack_item} ) {
        _pack_item( $handler );
    }

    # shipment box assigned
    if ( $handler->{param_of}{enter_box} ) {
        _assign_box( $handler );
    }

    # shipment box removed
    if ( $handler->{param_of}{remove_box} ) {
        _remove_box( $handler );
    }

    # item removed from shipment box
    if ( $handler->{param_of}{remove_item} ) {
        _remove_item_from_box( $handler );
    }

    # return waybill assigned
    if ( $handler->{param_of}{enter_waybill} ) {
        _assign_awb( $handler );
    }

    # return waybill removed
    if ( $handler->{param_of}{remove_waybill} ) {
        _remove_awb( $handler );
    }

    # complete button pressed
    if ( $handler->{param_of}{complete_pack} ) {
        $is_packing_complete = _complete_packing( $handler );
        # If we are truly finished packing this shipment then just redirect
        # without bothering to do the bits below. This currently occurs in DC3
        # where we do labelling when the user clicks on 'Complete Packing'
        if ( $is_packing_complete && $shipment->discard_changes && $shipment->pack_status->{pack_complete} ) {
            xt_success(sprintf 'Shipment %i has now been packed.', $shipment->id);
            if ( $shipment->display_no_returns_warning_after_packing ) {
                my @no_return_awb_display = ('******************',
                                             'Returns documentation will not be printed for this shipment as all shipment items are non-returnable',
                                             '******************');
                xt_success($_) for @no_return_awb_display;
            }
            return $handler->redirect_to( "/Fulfilment/Packing/CheckShipment?auto=completed&"
                . join '&', map {"shipment_id=$_"} @{$handler->{data}{container_ids}} );
        }
    }

    # get the info we need again to pick up changes
    $handler->{data}{shipment}->discard_changes;
    $handler->{data}{shipment_info}         = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
    $handler->{data}{shipment_boxes}        = get_shipment_boxes( $handler->{dbh}, $handler->{data}{shipment_id} );
    my $item_info = $handler->{data}{shipment_item_info} = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );

    # product images & shipping info
    foreach my $ship_item_id ( keys %{ $item_info } ) {

        # find out if the item is a Virtual Voucher
        if ( $item_info->{$ship_item_id}{voucher} && !$item_info->{$ship_item_id}{is_physical} ) {
            # if it is delete it from the list of items that will
            # be displayed in the packing pages
            delete $item_info->{$ship_item_id};
            next;
        }

        $item_info->{$ship_item_id}{ship_att} = get_product_shipping_attributes($handler->{dbh}, $item_info->{$ship_item_id}{product_id});
        $item_info->{$ship_item_id}{image} = get_images({
            product_id => $item_info->{$ship_item_id}{product_id},
            live => 1,
            schema => $handler->schema,
        });
        $item_info->{$ship_item_id}{product} = $handler->schema->resultset('Public::Product')->find($item_info->{$ship_item_id}{product_id});

        try {
            my $ship_restrictions = $item_info->{$ship_item_id}{product}->get_shipping_restrictions_status;
            $item_info->{$ship_item_id}{is_hazmat}    = $ship_restrictions->{is_hazmat};
            $item_info->{$ship_item_id}{is_aerosol}   = $ship_restrictions->{is_aerosol};
            $item_info->{$ship_item_id}{is_hazmat_lq} = $ship_restrictions->{is_hazmat_lq};
            # if any of the items in the shipment in hazmat_lq, then we need to show some
            # message in the temaplate
            $handler->{data}{is_shipment_hazmat_lq}   = 1 if ($ship_restrictions->{is_hazmat_lq});
        } catch {
            warn 'Product id is a voucher, no shipping restrictions';
        };
    }

    $handler->{data}{is_premier_shipment} = 1 if $shipment->is_premier;
    # get the status of the pack for use on screen
    $handler->{data}{pack_status} = $handler->{data}{shipment}->pack_status;

    # if all the items are packed then automatically show the box screen
    if ( ($handler->{data}{pack_status}{notready} == 0 && $handler->{data}{pack_status}{ready} == 0) && $handler->{data}{pack_status}{packed} > 0 && $handler->{data}{process} !~ /^complete/ ) {

        $handler->{data}{process} = 'box';

        # if all the items are packed go to the "waybill" or "complete" page
        if ($handler->{data}{pack_status}{assigned} == $handler->{data}{pack_status}{packed}) {

            # return AWB Required & NOT assigned
            # ensure that shipment is returnable otherwise no return AWB is generated
            # - show user the form input for return AWB
            if ( $shipment->is_returnable && !AWBs_are_present( { for => 'packing', on => $handler->{data}{shipment_info} } ) ) {
                $handler->{data}{waybill} = 1;
            }
            # Premier shipment
            # OR non-returnable DHL service
            # OR waybill assigned
            # OR UPS service (no AWB's required)
            # - show complete button
            else {
                $handler->{data}{complete} = 1;
            }
        }
    }

    # get list of available boxes for packing
    my $channel = $handler->schema->resultset('Public::Channel')->find($handler->{data}{sales_channel_id});

    my $active_boxes_rs = $channel->get_active_boxes;
    my (%active_boxes, @small_boxes, @large_boxes);
    while (my $box = $active_boxes_rs->next) {
        push @small_boxes, $box->box if $box->is_small;
        push @large_boxes, $box->box if $box->is_large;
        $active_boxes{$box->id} = $box;
    }

    my $active_inner_boxes_rs = $channel->get_active_inner_boxes;
    my %active_inner_boxes;
    while (my $inner_box = $active_inner_boxes_rs->next) {
        $active_inner_boxes{$inner_box->id} = $inner_box;
    }

    $handler->{data}{boxes}          = \%active_boxes;
    $handler->{data}{inner_boxes}    = \%active_inner_boxes;
    $handler->{data}{small_box_list} = \@small_boxes;
    $handler->{data}{large_box_list} = \@large_boxes;

    # freeze sticky page because packing is not complete
    if (not (
        $is_packing_complete
     || $shipment->discard_changes->pack_status->{pack_complete}
    )) {
        $handler->freeze_sticky_page( {
            sticky_class => 'Operator::StickyPage::Packing',
            sticky_id => $shipment->id,
            signature_object => $shipment,
        } );
    }

    return $handler->process_template;
}

sub _pack_item {
    my ($handler) = @_;

    # set process type to SKU
    $handler->{data}{process} = 'sku';

    # get the sku field from the form
    $handler->{data}{sku} = $handler->{param_of}{sku};

    if ( !$handler->{data}{sku} ) {
        # nothing was entered in the SKU field before form was submitted
        xt_warn 'No SKU entered, please try again.';
        return;
    }

    my $schema = $handler->{schema};
    my $dbh = $schema->storage->dbh;

    # 'pack' the shipment item in the system
    eval { $schema->txn_do( sub {
        # go through any Virtual Voucher Shipment Items
        # and update them to being 'Packed' first
        foreach my $si_id ( keys %{ $handler->{data}{shipment_item_info} } ) {
            my $item    = $handler->{data}{shipment_item_info}{ $si_id };

            if ( $item->{voucher}
                && !$item->{is_physical}
                && $item->{shipment_item_status_id} == $SHIPMENT_ITEM_STATUS__PICKED ) {
                # update shipment item status to be Packed
                my $shipment_item = $schema->resultset('Public::ShipmentItem')->find( $si_id );
                $shipment_item->update_status( $SHIPMENT_ITEM_STATUS__PACKED, $handler->operator_id );
            }
        }

        # get the shipment item from the shipment/SKU
        my $shipment_item_id = get_shipment_item_by_sku( $dbh, $handler->{data}{shipment_id}, $handler->{data}{sku} );

        if ( $shipment_item_id == 0 ) {
            # the SKU entered is not found in the shipment - error message
            xt_warn 'The sku entered could not be found in this shipment.  Please try again.';
        } elsif ( _item_can_be_packed( $handler, $shipment_item_id ) ) {
            # the SKU entered was found in the shipment

            # check shipment item status is Pickable

            # set a flag to see if it's ok to
            # pack the item from a DB point of view
            # NON Vouchers will go straight through
            my $ok_to_pack  = 1;

            my $item_info   = $handler->{data}{shipment_item_info}{$shipment_item_id};

            # if the SKU is a Voucher, if it's a Re-Shipment the code should already be assigned
            if ( $item_info->{voucher} && $handler->{data}{shipment_info}{shipment_class_id} != $SHIPMENT_CLASS__RE_DASH_SHIPMENT ) {
                $ok_to_pack = _check_voucher_code_ok( $schema, $handler, $item_info );
            }

            if ( $ok_to_pack ) {
                my $shipment_item   = $schema->resultset('Public::ShipmentItem')->find( $shipment_item_id );

                if ( $item_info->{voucher} && $handler->{data}{shipment_info}{shipment_class_id} != $SHIPMENT_CLASS__RE_DASH_SHIPMENT ) {
                    # if it's a voucher then set the 'voucher_code_id' on the
                    # shipment item record and set the voucher's 'assigned' date
                    my $voucher = $handler->{data}{voucher_to_use};
                    $shipment_item->voucher_code_id( $voucher->id );
                    $voucher->assigned_code();

                    # reset process to being 'sku' so as to get the next SKU from the user
                    $handler->{data}{process}   = 'sku';
                }
                # update status to Packed, and remove from original container
                $handler->{schema}
                            ->resultset('Public::ShipmentItem')
                            ->find($shipment_item_id)
                            ->unpick;

                $shipment_item->update_status( $SHIPMENT_ITEM_STATUS__PACKED, $handler->{data}{operator_id} );

                # log the pack in the stock log if its not a Re-Shipment
                if ( $handler->{data}{shipment_info}{shipment_class_id} != $SHIPMENT_CLASS__RE_DASH_SHIPMENT ) {
                    # get channel id
                    # TO DO - sample transfer doesn't have an order to get channel from
                    # once we work out how to channelise stock transfers we can get the right channel
                    my $channel_id = $handler->{data}{sales_channel_id};

                    die "No channel id for log_stock function" unless $channel_id;

                    log_stock(
                        $dbh,
                        {
                            variant_id  => $item_info->{variant_id},
                            action      => $STOCK_ACTION__ORDER,
                            quantity    => -1,
                            operator_id => $handler->{data}{operator_id},
                            notes       => $handler->{data}{shipment_id},
                            channel_id  => $channel_id
                        }
                    );
                }
            }
        }
    } ) };

    # if db update not successful output error message
    if ($@) {
        xt_warn "There was a problem trying to pack this item, please try again.  Error: ".strip_txn_do($@);
    }

    return;
}


sub _assign_box {
    my ($handler) = @_;

    # set process type to box
    $handler->{data}{process} = 'box';

    # TODO: http://jira4.nap/browse/DCA-912
    # 1. Bug here? array ref to an array?
    # 2. Also, should this be {data}{container_ids}, since that's
    # defaulted to the ones on the
    # $handler->{data}{shipment}->packable_container_ids
    # in the handler sub?
    my @srcs=$handler->{param_of}{container_ids};

    # box number & inner box number entered by user or
    # in the case of samples hardcoded in the template as before ( could there be a better way to achieve this ? )
    if ( $handler->{param_of}{outer_box_id} && $handler->{param_of}{inner_box_id} ){
        # check if shipment_box_id scanned
        $handler->{data}{shipment_box_id} = clean_shipment_box_id( $handler->{param_of}{shipment_box_id} );
        if ( !$handler->{data}{shipment_info}{orders_id} ) {

            # Sample orders don't scan shipment_box_id's
            # get next available shipment box id from db
            $handler->{data}{shipment_box_id} = get_shipment_box_id($handler->{dbh});
        }
        # User must have by-passed form validation
        elsif ( $handler->{data}{shipment_box_id} eq "" ) {
            xt_warn("Please scan a shipment barcode for this package/order.");
            return;
        }

        my $schema = $handler->{schema};
        my $dbh = $schema->storage->dbh;

        my $tote_id = $handler->{param_of}{tote_id};
        if($tote_id) {
            my $err;
            try {
                $tote_id = NAP::DC::Barcode::Container::Tote->new_from_id(
                    $handler->{param_of}{tote_id},
                );
                $err=0;
            }
            catch {
                $err=1;
                xt_warn($_);
            };
            return if $err;

            if ( $tote_id ~~ @srcs) {
                xt_warn 'You must use a new tote.';
                return;
            }
        }

        # WHM-1053: don't reuse box labels
        my $shipment_box_id = $handler->{data}{shipment_box_id};
        if ( $schema->resultset('Public::ShipmentBox')->find( $shipment_box_id ) ) {
            xt_warn "Box label $shipment_box_id has already been used. Please discard and scan a new one.";
            return;
        }

        # check if there are any shipment items still left to be boxed.
        # If not then we are here by mistake and we should not create a new shipment box
        my $create_shipment_box = 0;
        foreach my $shipment_item_id ( keys %{ $handler->{data}{shipment_item_info} } ) {
            my $shipment_item = $schema->resultset('Public::ShipmentItem')->find( $shipment_item_id );

            # virtual vouchers don't get packed in boxes
            next if ( $shipment_item->is_virtual_voucher );

            if ( !$shipment_item->is_boxed ) {
                $create_shipment_box = 1;
                last;
            }
        }

        if (!$create_shipment_box) {
            my $error_message = 'Shipment box not created. There is no shipment item remaining to be boxed for shipment ';
            xt_warn($error_message  . $handler->{data}{shipment_id});
            xt_logger->debug($error_message . pp($handler->{param_of}));
            return;
        }

        eval { $schema->txn_do( sub {
            # Assign box to the shipment
            $schema->resultset('Public::ShipmentBox')->create({
                id            => $shipment_box_id,
                shipment_id   => $handler->{data}{shipment_id},
                box_id        => $handler->{param_of}{outer_box_id},
                inner_box_id  => $handler->{param_of}{inner_box_id},
                ( $tote_id ? ( tote_id => $tote_id ) : () ),
                ( $handler->{param_of}{hide_from_iws} ?
                    ( hide_from_iws => 1 ) : () )
            });

            # assign the "packed" items which don't have a box to this box
            foreach my $shipment_item_id ( keys %{ $handler->{data}{shipment_item_info} } ) {
                my $shipment_item = $schema->resultset('Public::ShipmentItem')->find( $shipment_item_id );

                # virtual vouchers don't get packed in boxes
                next if ( $shipment_item->voucher_variant_id && !$shipment_item->voucher_variant->product->is_physical );

                if ( $shipment_item->is_packed && !$shipment_item->shipment_box_id ) {
                    $shipment_item->update({ shipment_box_id => $shipment_box_id });
                }
            }
        } ) };

        # if db update not successful output error message
        if ($@) {
            xt_warn 'An error occured whilst trying to update this shipment: '.strip_txn_do($@);
        }
    }

    return;
}


sub _remove_box {
    my ($handler) = @_;

    # set process type to box
    $handler->{data}{process} = 'box';

    # get the shipment box id from the users scan
    if ( my $shipment_box_id = clean_shipment_box_id( $handler->{param_of}{shipment_box_id} ) ) {
        my $schema = $handler->{schema};
        my $dbh    = $schema->storage->dbh;

        # get the shipment record
        my $shipment= $handler->{data}{shipment};

        eval { $schema->txn_do( sub {
            # remove the box id from any items with it assigned
            my $shipment_box = $schema->resultset('Public::ShipmentBox')->find( $shipment_box_id );
            for my $shipment_item ( $shipment_box->shipment_items ) {
                $shipment_item->update({ shipment_box_id => undef });
            }

            # delete the box from the db
            $shipment_box->delete;

            # if shipment is Carrier Automated then clear any carrier
            # automation data that may have been previously got as a change to
            # the box will mean a retry to the UPS API for data
            $shipment->discard_changes;
            if ( $shipment->is_carrier_automated ) {
                $shipment->clear_carrier_automation_data;
            }
        } ) };
        if (my $e = $@) {
            xt_warn(join q{<br />},
                'There was a problem removing the box: '.strip_txn_do($e),
                q{}, q{},
                'Please try again.'
            );
        }
    }

    return;
}


sub _remove_item_from_box {
    my ($handler) = @_;

    # set process type to box
    $handler->{data}{process} = 'box';

    # get the shipment box id from the users scan
    if ( $handler->{param_of}{item_id} ) {

        my $schema = $handler->{schema};
        my $dbh = $schema->storage->dbh;

        # get the shipment record
        my $shipment = $handler->{data}{shipment};
        eval { $schema->txn_do( sub {
            my $shipment_item_id = $handler->{param_of}{item_id};
            my $shipment_item = $schema->resultset('Public::ShipmentItem')->find( $shipment_item_id );
            my $shipment_box = $shipment_item->shipment_box;

            # remove the box id from the shipment item
            $shipment_item->update({ shipment_box_id => undef });

            # Delete box from shipment if there are no items left in it
            $shipment_box->delete unless $shipment_box->shipment_items->count;

            # if shipment is Carrier Automated then clear any carrier
            # automation data that may have been previously got as a change to
            # the box will mean a retry to the UPS API for data
            $shipment->discard_changes;
            $shipment->clear_carrier_automation_data if $shipment->is_carrier_automated;
        } ) };

        ## if db update not successful output error message
        if (my $e = $@) {
            xt_warn(join q{<br />},
                'There was a problem removing the item: '.strip_txn_do($e),
                q{}, q{},
                'Please try again.'
            );
        }
    }

    return;
}


sub _assign_awb {
    my ($handler) = @_;

    # set process type to box
    $handler->{data}{process} = 'box';

    # check if valid waybill entered by user
    if ($handler->{param_of}{return_waybill} && ( $handler->{param_of}{return_waybill} =~ m/\d{10}/ || $handler->{param_of}{return_waybill} =~ m/\w{1}\d{11}/ ) ){
        # strip any letters from waybill
        $handler->{param_of}{return_waybill} =~ s/[a-z]//gi;

        my $schema = $handler->{schema};
        my $dbh = $schema->storage->dbh;

        eval { $schema->txn_do( sub {
            # write waybill to the db
            log_dhl_waybill($dbh, $handler->{data}{shipment_id}, $handler->{param_of}{return_waybill}, "return");
        } ) };

        # if db update not successful output error message
        if ($@) {
            xt_warn 'An error occured whilst trying to update this shipment: '.strip_txn_do($@);
        }
    }
    else {
        xt_warn 'Please enter a valid waybill number.';
    }

    return;
}


sub _remove_awb {
    my ($handler) = @_;

    # set process type to box
    $handler->{data}{process} = 'box';

    my $schema = $handler->{schema};
    my $dbh = $schema->storage->dbh;

    eval { $schema->txn_do( sub {
        # remove waybill from the db
        log_dhl_waybill($dbh, $handler->{data}{shipment_id}, "none", "return");
    } ) };

    # if db update not successful output error message
    if ($@) {
        xt_warn 'An error occured whilst trying to update this shipment: '.strip_txn_do($@);
    }

    return;
}


sub _complete_packing {
    my ($handler) = @_;

    $handler->{data}{process} = 'complete';

    my $schema = $handler->{schema};
    my $dbh = $schema->storage->dbh;

    my $is_packing_complete = 0;

    my $shipment = $schema->resultset('Public::Shipment')->find($handler->{data}{shipment_id});

    # TODO: This transaction here does rather a lot and has caused minor "<IDLE> in transaction" blocking
    # processes in the past. Consider if transaction scope needs to be so large or if it could be
    # implemented as a series of smaller transactions
    eval { $schema->txn_do( sub {

        my $printer_data;
        my $packing_station_name = $handler->{data}{preferences}{packing_station_name};

        $printer_data = get_packing_station_printers(
            $schema,
            $packing_station_name
        );

        # print of Shipping input form for all non-premier shipments

        if (!$shipment->is_premier) {

            my $is_auto = $shipment->is_carrier_automated;

            if ( $is_auto ) {
                if ( $shipment->carrier_is_dhl ) {
                    # Print documents at packing complete unless fulfilment
                    # utilises labelling subsection
                    for my $box ($shipment->shipment_boxes) {
                        $box->label({
                            document_printer => $printer_data->{document},
                            label_printer    => $printer_data->{label},
                            operator_id      => $handler->operator_id,
                        });
                    }
                }
                else {
                    xt_logger->debug("PID:$$ Shipment $handler->{data}{shipment_id} is carrier automated");
                    if ( !AWBs_are_present( { for => 'CarrierAutomation', on => $handler->{data}{shipment_info} } ) ) {
                        # run the shipment pass the carrier automation process, if it fails this will return FALSE
                        # and we will be back to using the ye-olde manual process.
                        xt_logger->debug("PID:$$ Shipment " . $handler->{data}{shipment_id} . " going to process");
                        $is_auto    = process_shipment_for_carrier_automation( $schema, $handler->{data}{shipment_id}, $handler->operator_id );
                    }

                    # check if still an Automated Shipment
                        $shipment->discard_changes(); # Updated by previous line
                    if ( $is_auto ) {
                        # generate and print shipment paperwork & soon to be labels
                        $handler->{data}{process}   = 'complete_ca';
                        # Only distribution management can reprint CA paperwork
                        $handler->{data}{can_reprint} = 1
                            if $handler->{data}{department_id} == $DEPARTMENT__DISTRIBUTION_MANAGEMENT;
                        xt_logger->debug("PID:$$ Shipment " . $handler->{data}{shipment_id} . " - ca_success generate shipment paperwork");
                        generate_shipment_paperwork( $dbh, {
                                                    shipment_id     => $handler->{data}{shipment_id},
                                                    shipping_country=> $handler->{data}{shipment_address}{country},
                                                    packing_station => $packing_station_name,
                                               } );

                    } else {
                        # print of Shipping input form for automated shipments which failed the automation process and are now manual
                        $handler->{data}{process}   = 'complete_ca_fail';
                        xt_logger->debug("PID:$$ Shipment " . $handler->{data}{shipment_id} . " - ca_fail generate input form");
                    }
                }
            } else {
                # print of Shipping input form for all non-premier non-automated shipments
                xt_logger->debug("PID:$$ Shipment " . $handler->{data}{shipment_id} . " - manual - generate input form");
            }

            if (!$is_auto) {
                my $printer_type = 'Shipping';
                if ($handler->dc_name eq 'DC2') {
                    # get the document printer for the Packing Station
                    die "Can't Find a Document Printer for Packing Station: $packing_station_name"
                        unless $printer_data->{document};

                    $printer_type = $printer_data->{document};
                } else {

                    # This is quite confusing, but to get DHL labels, we call $box->label(). Deep in that call, there
                    # is logic that decides if this should be achieved using the DHL API or not.

                    # So... in DC1, we *DO* use the DHL API, but currently $is_auto will always return
                    # false regardless (!) and send us here. So we just call $box->label to get our labels.
                    # When $is_auto is sorted out, and it is only false when we do not want to call DHL, the
                    # $box->label() call should be skipped.

                    # In DC3, we don't yet use DHL automation, which means $is_auto will correctly be false.
                    # Calling $box->label is fine. When DC3 is moved over to use automation (and the $is_auto flag
                    # is fixed), it should skip the $box->label call at this point also.

                    # Oh and we only do this here if the extra 'labelling' section of XT is disabled

                    # Glad that's sorted then! :)

                    for my $box ($shipment->shipment_boxes) {
                        $box->label({
                            document_printer => $printer_data->{document},
                            label_printer    => $printer_data->{label},
                            operator_id      => $handler->operator_id,
                        });
                    }
                }
                generate_input_form( $handler->{data}{shipment_id}, $printer_type );
            }
        }
        # if Premier shipment then print off the paperwork if required by config
        # phase 2 is when we start printing at picking
        # Leave this config condition here in case we want to turn this off/on for some DCs
        elsif ( config_var('Print_Document', 'requires_premier_packing_printouts') ) {
            # DCA-307: Default premier printers have traditionally been these
            # two printers, shared between all packing stations.
            my $premier_doc_printer = 'Premier Shipping';
            my $premier_card_printer = 'Premier Address Card';

            # DCA-307: But if there's a premier card printer defined for this
            # packing station, we should try to use it and the associated
            # doc printer too.
            my $packstation_printers = get_packing_station_printers(
                $handler->{schema},
                $handler->{data}->{preferences}->{packing_station_name},
                1 # is_premier_station
            );

            if ( $handler->dc_name eq 'DC1' ) {
                # Get DC1 printers as for DC1 we do not(?)
                # have the default printers
                $premier_doc_printer  = $packstation_printers->{document};
                $premier_card_printer = ( $packstation_printers->{card} )
                    ? $packstation_printers->{card}
                    : undef;
            } elsif ($packstation_printers->{card}) {
                $premier_card_printer = $packstation_printers->{card};
                $premier_doc_printer = $packstation_printers->{document};
            }

            # Print premier documents
            my $box = $shipment->shipment_boxes->first;
            if ( $box ) {
                $box->label({
                    premier_printer   => $premier_doc_printer,
                    ( card_printer    => $premier_card_printer )x!! $premier_card_printer,
                    operator_id       => $handler->operator_id,
                });
            } else {
                die "No box assigned to shipment: " . $shipment->id;
            }
        }

        if ($handler->dc_name eq 'DC2') {
            if ($shipment->has_gift_messages() && !$shipment->can_automate_gift_message()) {

                die sprintf( "Can't Find a Document Printer for Packing Station: %s", $packing_station_name )
                    unless $printer_data->{document};

                $shipment->print_gift_message_warnings($printer_data->{document});
            }
        }

        if ($handler->{data}{shipment_info}{shipment_class_id} != $SHIPMENT_CLASS__RE_DASH_SHIPMENT) {
            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::WMS::ShipmentPacked',
                { shipment_id => $handler->{data}{shipment_id} }
            );
        }

        for my $shipment_box_row ($shipment->shipment_boxes) {
            XT::Data::PRL::Conveyor::Route::ToDispatch->new({
                shipment_box_row => $shipment_box_row,
                shipment_row     => $shipment,
            })->send();
        }

        if ( $handler->{data}{shipment_info}{type} eq 'Premier' ) {
            # send out Alerts to the Customer about their impending Delivery
            eval {
                my $shipment_rec    = $schema->resultset('Public::Shipment')->find( $handler->{data}{shipment_id} );
                $shipment_rec->send_routing_schedule_notification( $handler->msg_factory );
            };
            if ( my $err = $@ ) {
                warn "Couldn't send Premier Routing Notification to Shipment Id: " . $handler->{data}{shipment_id} . ", because: $err";
            }
        }
        $is_packing_complete = 1;
    } ) };

    if ($@){
        xt_logger->debug("PID:$$ Shipment " . $handler->{data}{shipment_id} . "rolling back");
        xt_logger->debug("PID:$$ $@");
        $handler->{data}{process}   = 'box';
        xt_warn 'There was a problem trying to complete the packing of this shipment, please try again.<br /><br />Error Message: '.strip_txn_do($@);
    }

    return $is_packing_complete;
}

=head2 _check_voucher_code_ok

    $boolean    = _check_voucher_code_ok( $dbh, $handler, $ship_item_info );

This checks that a Voucher SKU has had a Voucher Code scanned for it and that this code is Valid.

=cut

sub _check_voucher_code_ok {
    my ( $schema, $handler, $ship_item_info )   = @_;

    my $retval  = 0;

    my $voucher_code        = $handler->{param_of}{voucher_code};
    my $voucher_code_shown  = $handler->{param_of}{voucher_code_shown};

    $handler->{data}{process}   = 'sku_voucher';

    if ( (defined $voucher_code) && ( $voucher_code ne '') ) {
        # get the Voucher Codes that were QC'd
        my $qced_codes  = $handler->session->{pack_qc}{qced_codes};
        my $chkd_codes  = {};
        my $chkd_items  = {};
        # get previously checked codes and ship items from the session
        if ( defined $handler->session->{pack_qc}{scan_codes} ) {
            $chkd_codes = $handler->session->{pack_qc}{scan_codes};
        }
        if ( defined $handler->session->{pack_qc}{scan_items} ) {
            $chkd_items = $handler->session->{pack_qc}{scan_items};
        }

        my $ship_items  = $schema->resultset('Public::ShipmentItem')->search( { shipment_id => $handler->{data}{shipment_id} } );
        my $result      = $ship_items->check_voucher_code( {
                                                            for             => 'packing',
                                                            vcode           => $voucher_code,
                                                            shipment_item_id=> $ship_item_info->{id},
                                                            qced_codes      => $qced_codes,
                                                            chkd_codes      => $chkd_codes,
                                                            chkd_items      => $chkd_items,
                                                         } );
        if ( $result->{success} ) {
            # save voucher to use
            $handler->{data}{voucher_to_use}    = $result->{voucher_code};
            $retval = 1;
        }
        else {
            $handler->{data}{error_msg} = $voucher_code . ' - ' . $result->{err_msg};
            $retval = 0;
        }

        $handler->session->{pack_qc}{scan_codes}    = $chkd_codes;
        $handler->session->{pack_qc}{scan_items}    = $chkd_items;
    }
    else {
        if ( $voucher_code_shown ) {
            # only show this message if the Voucher Code prompt was shown
            $handler->{data}{error_msg} = "No Gift Card Code entered, please try again.";
        }
    }

    return $retval;
}

=head2 _item_can_be_packed

    $boolean    = _item_can_be_packed( $handler, $shipment_item_id );

This checks to see if a shipment item can be packed based on the statuses.

=cut

sub _item_can_be_packed {
    my ( $handler, $ship_item_id )  = @_;

    my $retval;

    my $item_info       = $handler->{data}{shipment_item_info}{$ship_item_id};
    my $item_status_id  = $item_info->{shipment_item_status_id};

    CASE: {
        if ( $item_status_id == $SHIPMENT_ITEM_STATUS__PICKED ) {   # 3
            if ( $item_info->{voucher} && !$item_info->{is_physical} ) {
                $retval = 0;
                $handler->{data}{error_msg} = "The item entered is for a Virtual Voucher and can't be Packed";
            }
            else {
                $retval = 1;
            }
            last CASE;
        }
        if ( $item_status_id == $SHIPMENT_ITEM_STATUS__NEW || $item_status_id == $SHIPMENT_ITEM_STATUS__SELECTED ) {   # 3
            $retval = 0;
            $handler->{data}{error_msg} = "The item entered is not ready to be packed.";
            last CASE;
        }
        if ( $item_status_id == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
             || $item_status_id == $SHIPMENT_ITEM_STATUS__CANCELLED ) {   # 9 || 10
            $retval = 0;
            $handler->{data}{error_msg} = "The item entered has been cancelled, please place the item back in stock.";
            last CASE;
        }
        $retval = 0;
        $handler->{data}{error_msg} = "The item entered has already been packed.";
    };

    return $retval;
}

=head2 clean_shipment_box_id

Read the shipment_box_id from the params, and return a cleaned version. Returns
a zero-width string if it can't find anything sensible

=cut

sub clean_shipment_box_id {
    my $shipment_box_id = shift;

    return q{} unless $shipment_box_id;
    ($shipment_box_id) = $shipment_box_id =~ m/(C?\d+)/i;

    return ucfirst($shipment_box_id);
}

1;
