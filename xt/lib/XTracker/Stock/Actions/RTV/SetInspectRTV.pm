package XTracker::Stock::Actions::RTV::SetInspectRTV;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Constants::FromDB         qw(:stock_process_type :stock_process_status :rtv_action :flow_status);
use XTracker::Database::Logging         qw(:rtv log_stock);
use XTracker::Database::RTV             qw(
    :rtv_stock
    :rtv_inspection
    :rtv_document
    update_fields
    get_parent_id
    create_rtv_stock_process
    get_rtv_print_location);
use XTracker::Database::StockProcess    qw(:iws);
use XTracker::Utilities                 qw(:edit url_encode);
use XTracker::Error;
use XTracker::Config::Local             'config_var';
use XTracker::Document::RTVStockSheet;

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # grab search params from url so we can redirect back to same list
    my $product_id  = $handler->{param_of}{product_id};
    my $channel_id  = $handler->{param_of}{channel_id};

    my $redirect_url    = '/RTV/FaultyGI?redir=1';

    my $response;

    my @skipped=();
    my @processed=();

    eval {

        my $schema = $handler->schema;
        my $dbh = $schema->storage->dbh;
        my $guard = $schema->txn_scope_guard;
        # update fault data
        if ( $handler->{param_of}{'submit_update_fault_data'} ) {
            my %updated_ids;

            $redirect_url   .= '&product_id='.$product_id.'&channel_id='.$channel_id.'&display_workstation_drilldown=1&display_list=0';

            ## Update edited fault type & description
            foreach my $field ( keys %{$handler->{param_of}} ) {
                if ( $field =~ m/fault_description_(\d+)/ || $field =~ m/ddl_item_fault_type_(\d+)/ ) {

                    my $rtv_quantity_id = $1;

                    my $fault_type_id       = $handler->{param_of}{'ddl_item_fault_type_'.$rtv_quantity_id};
                    my $fault_description   = $handler->{param_of}{'fault_description_'.$rtv_quantity_id};

                    next        unless (defined $fault_type_id or defined $fault_description);
                    next        if ( exists( $updated_ids{$rtv_quantity_id} ) );

                    insert_update_delivery_item_fault({
                        dbh                 => $dbh,
                        type                => 'rtv_quantity_id',
                        id                  => $rtv_quantity_id,
                        fault_type_id       => $fault_type_id,
                        fault_description   => $fault_description,
                    });

                    $updated_ids{$rtv_quantity_id}  = 1;
                }
            }

            $response       = "Fault data updated successfully.";
        }
        # generate a pick request
        elsif ( $handler->{param_of}{'submit_inspection_request'} ) {

            $product_id //= '';
            $channel_id //= '';

            $redirect_url   .= '&product_id='.$product_id.'&channel_id='.$channel_id.'&display_list=inspection';

            my @include_products    = ();

            foreach my $field ( keys %{$handler->{param_of}} ) {
                if ( ($field =~ m/^include_(\d+)_(\d+)/) && $handler->{param_of}{$field} ) {
                    push @include_products, { product_id => $1, delivery_id => $2 };
                }
            }
            die 'No products were selected' unless scalar @include_products;

            ## create inspection pick request
            my $rtv_inspection_pick_request_id = create_rtv_inspection_pick_request({
                        dbh             => $dbh,
                        products_ref    => \@include_products,
                        operator_id     => $handler->{data}{operator_id},
            });

            # create RTV inspection picklist
            my $doc_name = create_rtv_inspection_picklist({
                    dbh                             => $dbh,
                    rtv_inspection_pick_request_id  => $rtv_inspection_pick_request_id,
            });

            my $single_product_id = $include_products[0]->{product_id};
            my $single_product = $schema->resultset('Public::Product')->find({ id => $single_product_id });
            my $config_section = $single_product->get_product_channel()->channel->config_name;
            my $printer_name = config_var('InspectRTVChannelPrinterName', $config_section);
            print_rtv_document( { document => $doc_name, printer_name => $printer_name } );

            $response       = "Inspection request created successfully.";
        }
        # set decision on stock in workstation
        elsif ( $handler->{param_of}{'submit_workstation_decision'} ) {

            $redirect_url   .= '&product_id='.$product_id.'&channel_id='.$channel_id.'&display_list=workstation';

            my %stock_process_group = ();

            RTV_QUANTITY_ID:
            foreach my $field ( keys %{$handler->{param_of}} ) {
                if ( $field =~ m/edit_main_qty_(\d+)/ ) {

                    my $rtv_quantity_id = $1;

                    my $sku = $handler->{param_of}{'sku_'.$rtv_quantity_id};

                    my %entered_qty     = ();
                    $entered_qty{rtv}   = $handler->{param_of}{'rtv_qty_'.$rtv_quantity_id}  ? $handler->{param_of}{'rtv_qty_'.$rtv_quantity_id}  : 0;
                    $entered_qty{main}  = $handler->{param_of}{'main_qty_'.$rtv_quantity_id} ? $handler->{param_of}{'main_qty_'.$rtv_quantity_id} : 0;
                    $entered_qty{dead}  = $handler->{param_of}{'dead_qty_'.$rtv_quantity_id} ? $handler->{param_of}{'dead_qty_'.$rtv_quantity_id} : 0;


                    ## ignore row if all fields are blank/zero
                    next RTV_QUANTITY_ID unless ( $entered_qty{rtv} || $entered_qty{main} || $entered_qty{dead} );

                    my %process_qty = ();

                    ## ignore row if any fields are invalid
                    foreach ( qw(rtv main dead) ) {
                        if ( $entered_qty{$_} =~ m{\A\d+\z}xms ) {
                            $process_qty{$_} = $entered_qty{$_};
                        }
                        else {
                            push @skipped, "Skipped SKU $sku. Invalid value entered for $_ quantity";

                            next RTV_QUANTITY_ID;
                        }
                    }

                    my $total_qty           = $process_qty{main} + $process_qty{rtv} + $process_qty{dead};
                    my $rtv_stock_ref       = get_rtv_stock( { dbh => $dbh, type => 'rtv_quantity_id', id => $rtv_quantity_id } )->[0];
                    my $delivery_item_id    = $rtv_stock_ref->{delivery_item_id};
                    my $current_quantity    = $rtv_stock_ref->{quantity};

                    if ($rtv_stock_ref->{quantity_status_id} != $FLOW_STATUS__RTV_WORKSTATION__STOCK_STATUS) {
                        push @skipped, "SKU $sku was skipped! Invalid stock status '$rtv_stock_ref->{quantity_status_id}'" ;

                        next RTV_QUANTITY_ID;
                    }

                    ## ensure submitted total is actually possible
                    if ( $total_qty > $current_quantity ) {
                        push @skipped, "SKU $sku was skipped! Quantity mismatch - submitted total $total_qty exceeds line quantity $current_quantity";

                        next RTV_QUANTITY_ID;
                    }

                    ## if submitted total isn't everything, some remains in RTV.
                    ## that's ok, because processed stuff gets moved into new
                    ## process groups

                    ## store the fault description first
                    my $fault_type_id       = $handler->{param_of}{'ddl_item_fault_type_'.$rtv_quantity_id};
                    my $fault_description   = $handler->{param_of}{'fault_description_'.$rtv_quantity_id};

                    if (defined $fault_type_id or defined $fault_description) {
                        insert_update_delivery_item_fault({
                            dbh                 => $dbh,
                            type                => 'delivery_item_id',
                            id                  => $delivery_item_id,
                            fault_type_id       => $fault_type_id,
                            fault_description   => $fault_description,
                        });
                    }

                    ## move RTV stock out, and insert log_rtv_stock records
                    foreach ( keys %process_qty ) {

                        next unless $process_qty{$_} > 0;

                        $stock_process_group{$_}{$delivery_item_id} += $process_qty{$_};

                        move_rtv_stock_out({
                            dbh             => $dbh,
                            rtv_stock_type  => 'RTV Workstation',
                            type            => 'rtv_quantity_id',
                            id              => $rtv_quantity_id,
                            quantity        => $process_qty{$_},
                        });

                        my %action_lookup = (
                            rtv => {
                                GI  => $RTV_ACTION__GI_FAULTY_RTV,
                                CR  => $RTV_ACTION__CR_FAULTY_RTV,
                            },
                            main => {
                                GI  => $RTV_ACTION__GI_FAULTY_FIXED,
                                CR  => $RTV_ACTION__CR_FAULTY_FIXED,
                            },
                            dead => {
                                GI  => $RTV_ACTION__GI_FAULTY_DEAD,
                                CR  => $RTV_ACTION__CR_FAULTY_DEAD,
                            },
                        );

                        log_rtv_stock({
                            dbh             => $dbh,
                            variant_id      => $rtv_stock_ref->{variant_id},
                            rtv_action_id   => $action_lookup{$_}{ $rtv_stock_ref->{origin} },
                            quantity        => ($process_qty{$_} * -1),
                            operator_id     => $handler->{data}{operator_id},
                            notes           => "RTV Workstation to Putaway",
                            channel_id      => $rtv_stock_ref->{channel_id},
                        });
                    }

                    push @processed, $sku;
                }

            } ## END foreach RTV_QUANTITY_ID

            my %stock_process_type_id = (
                rtv     => $STOCK_PROCESS_TYPE__RTV,
                main    => $STOCK_PROCESS_TYPE__RTV_FIXED,
                dead    => $STOCK_PROCESS_TYPE__DEAD,
            );

            ## create stock_process records and print associated stock sheets
            foreach my $process_type (keys %stock_process_group) {

                my $group       = 0;
                my $delivery_id = 0;

                foreach my $delivery_item_id ( sort keys %{ $stock_process_group{$process_type} } ) {

                    $delivery_id = get_parent_id({ dbh => $dbh, type => 'delivery_item', id => $delivery_item_id } ) unless $group;

                    my $stock_process_id = create_rtv_stock_process({
                            dbh                     => $dbh,
                            stock_process_type_id   => $stock_process_type_id{$process_type},
                            delivery_item_id        => $delivery_item_id,
                            quantity                => $stock_process_group{$process_type}{$delivery_item_id},
                            process_group_ref       => \$group,
                            stock_process_status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
                            originating_path        => $r->parsed_uri->path,
                    });
                }

                if ($process_type eq 'main' || $process_type eq 'dead') {
                    send_pre_advice($handler->msg_factory,
                                    $schema,
                                    $group,
                                    $stock_process_type_id{$process_type},
                                    $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED);
                }

                my $document = XTracker::Document::RTVStockSheet->new(
                    group_id        => $group,
                    document_type   => $process_type,
                    origin          => 'rtv_workstation'
                );

                my $channel_id = $document->delivery->stock_order->product->get_product_channel->channel->id;

                my $print_location = get_rtv_print_location($schema, $channel_id);

                $document->print_at_location($print_location);
            }

            if (@processed == 1) {
                $response = "RMA Details updated successfully for SKU: ".$processed[0];
            }
            elsif (@processed > 1) {
                $response = "RMA Details updated successfully for SKUs: ".join(', ',( sort { $a cmp $b } @processed));
            }
        }

        $guard->commit();

        xt_warn(join('; ',sort { $a cmp $b } @skipped)) if @skipped;
        xt_success($response) if $response;
    };

    if ($@) {
        my $error = $@;         # in case rollback poops on it
        xt_warn("An error occured: $error");
    }

    return $handler->redirect_to( $redirect_url );
}



1;
