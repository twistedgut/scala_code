package XTracker::Stock::Actions::SetSampleVendorGoodsIn;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Constants::FromDB         qw(
                                            :delivery_action
                                            :delivery_item_status
                                            :delivery_status
                                            :delivery_type
                                            :flow_status
                                            :shipment_status
                                            :stock_action
                                            :stock_process_status
                                            :stock_process_type
                                        );
use XTracker::Database::Delivery        qw( complete_delivery complete_delivery_item create_delivery get_delivery_items
                                            set_delivery_status set_delivery_item_quantity set_delivery_item_status );
use XTracker::Database::Logging         qw( log_delivery log_stock );
use XTracker::Database::PurchaseOrder   qw( set_stock_order_item_status );
use XTracker::Database::Product         qw( get_variant_id get_product_data get_variant_list get_variant_id_by_type get_variant_details );
use XTracker::Database::Shipment        qw( get_shipment_id update_shipment_status update_shipment_item_status );
use XTracker::Database::Sample          qw( get_vendor_sample_shipment_items get_variant_from_delivery_item
                                            update_shipment_item_variant get_stock_variant_id_from_variant );
use XTracker::Database::Stock           qw( update_quantity
                                            insert_quantity delete_quantity
                                            check_stock_location get_stock_location_quantity );
use XTracker::Database::StockProcess    qw( set_process_group_status create_stock_process get_process_group_id
                                            get_process_group_type get_process_group_total set_stock_process_type );
use XTracker::PrintFunctions            qw( print_label get_printer_by_name );
use XTracker::Utilities                 qw( url_encode );
use XTracker::XTemplate;
use XTracker::Config::Local qw( config_var );
use XTracker::Error;

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $psku                = $handler->{param_of}{psku};
    my $channel_id          = $handler->{param_of}{channel_id};
    my $qc_shipment_item_id = $handler->{param_of}{qc_shipment_item_id};
    my $fault_reason        = $handler->{param_of}{fault_reason};
    my $large_variant_id    = ( $handler->{param_of}{large_variant_id} ? 1 : 0 );
    my $small_variant_id    = ( $handler->{param_of}{small_variant_id} ? 1 : 0 );

    my $ret_params          = "";
    my $error               = "";
    my $success_msg         = "";
    my $prod_shipment_dets;
    my $product_id;
    my $size_id;

    my $guard = $handler->schema->txn_scope_guard;
    # check if all params needed are present and then set up a few basics for the rest of the script
    if ( !$psku || !$channel_id || !$qc_shipment_item_id ) {
        $error  = "No SKU / Product Quality / Sales Channel supplied";
    }
    else {
        ( $product_id, $size_id )   = split( /-/, $psku );
        $prod_shipment_dets = get_vendor_sample_shipment_items( $handler->{dbh}, { product_id => $product_id, size_id => $size_id, channel_id => $channel_id } );
        if ( !$prod_shipment_dets ) {
            $error  = "Invalid SKU: ".$psku;
        }
        elsif ( $qc_shipment_item_id == 2 && $fault_reason eq "" ) {
            $error  = "You must specify a Reason if you want to mark this product as Faulty";
        }
    }

    if ( $error eq "" ) {

        eval {
            if ( $qc_shipment_item_id == 1 ) {

                my $variant_id  = get_variant_id( $handler->{dbh}, { product_id => $product_id, size_id => $size_id } );

                _put_vendor_sample_shipment_items( $handler->{dbh}, $handler, {
                                    shipment_item_id    => $prod_shipment_dets->{shipment_item_id},
                                    large_print         => ( $large_variant_id ? $variant_id : 0 ),
                                    small_print         => ( $small_variant_id ? $variant_id : 0 ),
                                    channel_id          => $channel_id
                } );

                $success_msg    = " as Passed";
            }

            if ( $qc_shipment_item_id == 2 ) {

                my $stock_variant_id    = get_variant_id( $handler->{dbh}, { product_id => $product_id, size_id => $size_id, type => 'stock' } );
                my $sample_variant_id   = get_variant_id_by_type( $handler->{dbh}, { variant_id => $stock_variant_id, from_type => 'Stock', to_type => 'Sample' } );
                my $shipment_item_id    = $prod_shipment_dets->{shipment_item_id};

                _put_vendor_sample_shipment_faulty_items( $handler->{dbh}, $handler, {
                                    variant_id       => $sample_variant_id,
                                    product_id       => $product_id,
                                    size_id          => $size_id,
                                    reason_id        => $fault_reason,
                                    shipment_item_id => $shipment_item_id,
                                    channel_id       => $channel_id,
                                    print_large      => $large_variant_id,
                                    print_small      => $small_variant_id
                } );

                $success_msg    = " as Faulty";
            }
            $guard->commit;
            $success_msg    = "SKU: ".$psku." was set ".$success_msg;
        };
        if ( $@ ) {
            $error  = $@
        }
    }

    if ( $error ne "" ) {
        $ret_params = "scan=1";
        $ret_params .= "&psku=".$psku;
        $ret_params .= "&channel_id=".$channel_id;
        xt_warn($error);
    }
    else {
        xt_success($success_msg);
    }

    return $handler->redirect_to( '/GoodsIn/VendorSampleIn?'.$ret_params );
}

sub _put_vendor_sample_shipment_faulty_items {

    my ( $dbh, $handler, $args )    = @_;

    my $product_id          = $args->{product_id};
    my $size_id             = $args->{size_id};
    my $reason_id           = $args->{reason_id};
    my $shipment_item_id    = $args->{shipment_item_id};
    my $channel_id          = $args->{channel_id};
    my $print_large         = $args->{print_large};
    my $print_small         = $args->{print_small};

    my @delivery;

    my $delivery_item = {
        shipment_item_id => $shipment_item_id,
        packing_slip     => 1,                  # 1 item
        type_id          => $DELIVERY_TYPE__SAMPLE_ORDER,                  # Vendor Sample Order
    };

    push @delivery, $delivery_item;

    my $delivery    = { delivery_type_id => $DELIVERY_TYPE__SAMPLE_ORDER, delivery_items => \@delivery, };    # Sample Order
    my $delivery_id = create_delivery( $dbh, $delivery );
    my $shipment_id = get_shipment_id ( $dbh, { id => $shipment_item_id, type => 'shipment_item_id' } );

    update_shipment_status( $dbh, $shipment_id, $SHIPMENT_STATUS__RECEIVED, $handler->operator_id );   # Received

    my $group_id    = 0;
    my $stock_process_id;

    foreach my $delivery_items_ref ( @{ get_delivery_items( $dbh, $delivery_id ) } ) {

        my $delivery_item_id    = $delivery_items_ref->[0];

        $stock_process_id       = create_stock_process( $dbh, $STOCK_PROCESS_TYPE__FAULTY, $delivery_item_id, 1, \$group_id );    # Faulty

        set_delivery_item_quantity( $dbh, $delivery_item_id, 1 );
        set_delivery_item_status( $dbh, $delivery_id, 'delivery_item_id', $DELIVERY_ITEM_STATUS__PROCESSING );  # Delivery Status? Processing

        if ( my $variant_id = get_variant_from_delivery_item( $dbh, { delivery_item_id => $delivery_item_id, clause => 'shipment_item' } ) ) {

            update_shipment_item_status( $dbh, $shipment_item_id, $SHIPMENT_STATUS__RECEIVED ); # Shipment Status? Received

            my $process_group_id    = get_process_group_id( $dbh, $stock_process_id );

            set_process_group_status( $dbh, $process_group_id, $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED ); # Bagged and Tagged - move to put away list
            set_stock_process_type( $dbh, $stock_process_id, $STOCK_PROCESS_TYPE__DEAD );   # Dead

            my $delivery_args = {
                type_id       => get_process_group_type( $dbh, $process_group_id ),
                quantity      => get_process_group_total( $dbh, $process_group_id ),
                operator      => $handler->operator_id,
                action        => $DELIVERY_ACTION__BAG_AND_TAG,  # bag and tag
                delivery_id   => $delivery_id,
                location_type => 'Sample',
            };

            log_delivery( $dbh, $delivery_args );

            my $stock_variant_id    = convert_variant_type( $dbh, {
                            from_type   => 'Sample',
                            to_type     => 'Stock',
                            variant_id  => $variant_id,
                            location    => 'Transfer Pending',
                            channel_id  => $args->{channel_id},
                            quantity    => 1,
                            status_id   => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                        } );

            update_shipment_item_variant( $dbh, {
                            process_group_id    => $process_group_id,
                            sample_variant_id   => $variant_id,
                            stock_variant_id    => $stock_variant_id
            } );

                        $handler->msg_factory->transform_and_send('XT::DC::Messaging::Producer::WMS::PreAdvice',{
                            sp => $handler->schema->resultset('Public::StockProcess')
                                ->find($stock_process_id),
                        });

            # print a process label
            _print_return_label( $handler, $stock_process_id, $stock_variant_id, "Faulty" );

            if ( $args->{print_large} ) {
                eval{ print_label( $dbh, { department_id => $handler->department_id, type => 'variant_id', id => $stock_variant_id, print_large => 1, num_large => 1, } ); };
            }

            if ( $args->{print_small} ) {
                eval{ print_label( $dbh, { department_id => $handler->department_id, type => 'variant_id', id => $stock_variant_id, print_small => 1, num_small => 1, } ); };
            }
        }
    }

    set_delivery_status( $dbh, $delivery_id, 'delivery_id', $DELIVERY_STATUS__PROCESSING );
}

sub _put_vendor_sample_shipment_items {

    my ( $dbh, $handler, $args ) = @_;

    if ( $args->{shipment_item_id} ) {

        my $shipment_item_id    = $args->{shipment_item_id};

        my @delivery;

        my $delivery_item   = {
            shipment_item_id    => $shipment_item_id,
            packing_slip        => 1,
            type_id             => $DELIVERY_TYPE__SAMPLE_ORDER,
        };
        push @delivery, $delivery_item;

        my $delivery    = { delivery_type_id => $DELIVERY_TYPE__SAMPLE_ORDER, delivery_items => \@delivery, };
        my $delivery_id = create_delivery( $dbh, $delivery );
        my $shipment_id = get_shipment_id ( $dbh, { id => $shipment_item_id, type => 'shipment_item_id' } );

        update_shipment_status( $dbh, $shipment_id, $SHIPMENT_STATUS__RECEIVED, $handler->operator_id );

        my $group_id    = 0;
        my $stock_process_id;

        foreach my $delivery_items_ref ( @{ get_delivery_items( $dbh, $delivery_id ) } ) {

            my $delivery_item_id    = $delivery_items_ref->[0];

            $stock_process_id       = create_stock_process( $dbh, $STOCK_PROCESS_TYPE__MAIN, $delivery_item_id, 1, \$group_id );

            set_delivery_item_quantity( $dbh, $delivery_item_id, 1 );
            set_delivery_item_status( $dbh, $delivery_id, 'delivery_item_id', $DELIVERY_ITEM_STATUS__COMPLETE );
            complete_delivery_item( $dbh, { type => 'stock_process', id => $stock_process_id } );

            if ( my $variant_id = get_variant_from_delivery_item( $dbh, { delivery_item_id => $delivery_item_id, clause => 'shipment_item' } ) ) {

                update_shipment_item_status( $dbh, $shipment_item_id, $SHIPMENT_STATUS__RECEIVED );

                my $process_group_id = get_process_group_id( $dbh, $stock_process_id );

                set_process_group_status( $dbh, $process_group_id, $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED );

                my $delivery_args = {
                                    type_id       => get_process_group_type( $dbh, $process_group_id ),
                                    quantity      => get_process_group_total( $dbh, $process_group_id ),
                                    operator      => $handler->operator_id,
                                    action        => $DELIVERY_ACTION__PUTAWAY,
                                    delivery_id   => $delivery_id,
                                    location_type => 'Sample',
                };

                log_delivery( $dbh, $delivery_args );

                my $stock_variant_id    = convert_variant_type( $dbh, {
                                    from_type  => 'Sample',
                                    to_type    => 'Stock',
                                    variant_id => $variant_id,
                                    location   => 'Transfer Pending',
                                    channel_id => $args->{channel_id},
                                    quantity   => 1,
                                    status_id  => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                                } );

                log_stock($dbh, {
                                    variant_id  => $variant_id,
                                    action      => $STOCK_ACTION__PUT_AWAY,
                                    quantity    => 1,
                                    operator_id => $handler->operator_id,
                                    notes       => 'From Sample Room',
                                    channel_id  => $args->{channel_id}
                });

                update_shipment_item_variant( $dbh, {
                                    process_group_id  => $process_group_id,
                                    sample_variant_id => $variant_id,
                                    stock_variant_id  => $stock_variant_id
                } );

                $handler->msg_factory->transform_and_send('XT::DC::Messaging::Producer::WMS::PreAdvice',{
                    sp => $handler->schema->resultset('Public::StockProcess')
                        ->find($stock_process_id),
                });

                # print a process label
                _print_return_label( $handler, $stock_process_id, $stock_variant_id );
            }
        }

        set_delivery_status( $dbh, $delivery_id, 'delivery_id', $DELIVERY_STATUS__PROCESSING );
        complete_delivery( $dbh, { type => 'stock_process', id => $stock_process_id } );
    }

    if ( $args->{large_print} ) {

        my $variant_id  = $args->{large_print};

        next            if ( $variant_id eq 'variant_id' );

        my $stock_variant_id    = get_stock_variant_id_from_variant( $dbh, { id => $variant_id } );
        eval{ print_label( $dbh, { department_id => $handler->department_id, type => 'variant_id', id => $stock_variant_id, print_large => 1, num_large => 1, } ); };

    }

    if ( $args->{small_print} ) {

        my $variant_id = $args->{small_print};

        next if ( $variant_id eq 'variant_id' );

        my $stock_variant_id = get_stock_variant_id_from_variant( $dbh, { id => $variant_id } );
        eval{ print_label( $dbh, { department_id => $handler->department_id, type => 'variant_id', id => $stock_variant_id, print_small => 1, num_small => 1, } ); };

    }
}

### Subroutine : _print_return_label                                    ###
# usage        : _print_return_label(                                     #
#                      $handler,                                          #
#                      $stock_process_id,                                 #
#                      $variant_id,                                       #
#                      $type                                              #
#                  );                                                     #
# description  : Used to print a label for the new Stock Process created  #
#              : by the above 2 functions. The variant id is used to get  #
#                th SKU.                                                  #
# parameters   : A Handler, The Stock Process Id, The Id of the           #
#                Variant to produce the labelf for and the Type which is  #
#                either empty or 'Faulty' to indicate a faulty item being #
#                processed.                                               #
# returns      : Nothing.                                                 #

sub _print_return_label {
    my ( $handler, $stock_process_id, $variant_id, $type )  = @_;

    my $label_data;
    my $label;
    my $l_template;
    my $printer_info;

    my $dbh = $handler->dbh;
    my $variant_dets    = get_variant_details( $dbh, $variant_id );
    my $process_group_id= get_process_group_id( $dbh, $stock_process_id );

    # set-up label information for TT process
    if ($handler->iws_rollout_phase == 0) {
        $label_data->{group_id} = $process_group_id;
    }
    else {
        $label_data->{group_id} = 'p-'.$process_group_id;
    }
    $label_data->{sku}      = $variant_dets->{sku};
    $label_data->{type}     = "F"       if ( defined $type && $type eq "Faulty" );

    # create label
    $l_template = XTracker::XTemplate->template();
    $l_template->process( 'print/returns_label.tt', { template_type => 'none', %$label_data }, \$label );

    # write to file
    my $label_path = XTracker::PrintFunctions::path_for_print_document({
        document_type => 'label',
        id => join('_', grep { defined && length } $stock_process_id, $label_data->{group_id}),
        extension => 'lbl',
    });

    open my $fh, ">", $label_path || die print "Couldn't open label file: $!";
    print $fh $label;
    close $fh;

    # print it
    my $stock_process = $handler->schema->resultset('Public::StockProcess')->find({ id => $stock_process_id });
    my $printer_name = config_var('SampleVendorGoodsInChannelPrinterName', $stock_process->channel->config_name);
    $printer_info = get_printer_by_name($printer_name);

    # did we find the printer?
    if ($printer_info->{lp_name}) {
        XT::LP->print(
            {
                printer     => $printer_info->{lp_name},
                filename    => $label_path,
                copies      => 1,
            }
        );
    }
    return;
}

=pod convert_variant_type

Convert a Variant from one type to another.

my $stock_variant_id = convert_variant_type( $dbh, { from => 'Sample', to => 'Stock', variant_id => $id, location => 'Transfer Pending', quantity => 1, status_id   => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS } );

=cut

sub convert_variant_type {

    my ( $dbh, $args )  = @_;

    update_quantity( $dbh, {
        variant_id         => $args->{variant_id},
        "location"         => $args->{location},
        quantity           => ($args->{quantity}*-1),
        type               => 'dec',
        channel_id         => $args->{channel_id},
        current_status_id  => $args->{status_id},
        next_status_id     => $args->{status_id},
    } );

    if ( get_stock_location_quantity( $dbh, {
        "variant_id"  => $args->{variant_id},
        "location"    => $args->{location},
        "channel_id"  => $args->{channel_id},
        status_id     => $args->{status_id},
    } ) <= 0 ) {
        delete_quantity( $dbh, {
            "variant_id"   => $args->{variant_id},
            "location"     => $args->{location},
            "channel_id"   => $args->{channel_id},
            status_id      => $args->{status_id},
        } );
    }

    my $variant_id  = get_variant_id_by_type( $dbh, { variant_id => $args->{variant_id}, from_type => $args->{from_type}, to_type => $args->{to_type}, } );

    if ( check_stock_location( $dbh, {
        "variant_id" => $variant_id,
        "location"   => $args->{location},
        "channel_id" => $args->{channel_id},
        status_id    => $args->{status_id},
    } ) > 0 ) {
        update_quantity( $dbh, {
            "variant_id"       => $variant_id,
            "location"         => $args->{location},
            quantity           => $args->{quantity},
            type               => 'inc',
            "channel_id"       => $args->{channel_id},
            current_status_id  => $args->{status_id},
            next_status_id     => $args->{status_id},
        } );
    }
    else {
        insert_quantity( $dbh, {
            "variant_id"       => $variant_id,
            "location"         => $args->{location},
            quantity           => $args->{quantity},
            "channel_id"       => $args->{channel_id},
            initial_status_id  => $args->{status_id},
        } );
    }

    return $variant_id
}

1;
