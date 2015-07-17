package XTracker::Stock::RTV::DispatchedRTV;

use strict;
use warnings;
use Data::Dumper;

use Hash::Util                          qw(lock_hash);
use URI;

use XTracker::Error;
use XTracker::Handler;
use XTracker::Constants::FromDB         qw(:rtv_shipment_status :rtv_shipment_detail_result_type :stock_process_type :stock_process_status);
use XTracker::Database::RTV             qw(:rma_request :rtv_shipment :rtv_shipment_result
                                           :rtv_stock :rtv_document :validate list_countries
                                           get_parent_id create_rtv_stock_process get_rtv_print_location);
use XTracker::Document::RTVStockSheet;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $RTV_CONSTANTS_REF = {
        RTV_SHIP_STAT_AWAITING_DISPATCH         => $RTV_SHIPMENT_STATUS__AWAITING_DISPATCH,
        RTV_SHIP_STAT_DISPATCHED                => $RTV_SHIPMENT_STATUS__DISPATCHED,
        RTV_SHIP_STAT_HOLD                      => $RTV_SHIPMENT_STATUS__HOLD,
        RTV_SHIP_DET_RESULT_TYPE_CREDITED       => $RTV_SHIPMENT_DETAIL_RESULT_TYPE__CREDITED,
        RTV_SHIP_DET_RESULT_TYPE_REPAIRED       => $RTV_SHIPMENT_DETAIL_RESULT_TYPE__REPAIRED,
        RTV_SHIP_DET_RESULT_TYPE_REPLACED       => $RTV_SHIPMENT_DETAIL_RESULT_TYPE__REPLACED,
        RTV_SHIP_DET_RESULT_TYPE_DEAD           => $RTV_SHIPMENT_DETAIL_RESULT_TYPE__DEAD,
        RTV_SHIP_DET_RESULT_TYPE_STOCK_SWAPPED  => $RTV_SHIPMENT_DETAIL_RESULT_TYPE__STOCK_SWAPPED,
    };
    lock_hash(%$RTV_CONSTANTS_REF);

    $handler->{data}{section}               = 'RTV';
    $handler->{data}{subsection}            = 'Dispatched Shipments';
    $handler->{data}{subsubsection}         = '';
    $handler->{data}{content}               = 'rtv/dispatched_rtv.tt';
    $handler->{data}{tt_process_block}      = undef;
    $handler->{data}{rtv_constants}         = $RTV_CONSTANTS_REF;
    $handler->{data}{rma_list}              = undef;
    $handler->{data}{filter_msgs}           = [];


    $handler->{data}{rma_request_id}  = $handler->{param_of}{rma_request_id} // q{};
    $handler->{data}{rtv_shipment_id} = $handler->{param_of}{rtv_shipment_id} // q{};

    ## remove 'RTVS-' prefix if necessary (i.e. for scanned input)
    $handler->{data}{rtv_shipment_id}   = $handler->{data}{rtv_shipment_id} =~ m{\ARTVS-(\d+)\z}xms ? $1 : $handler->{data}{rtv_shipment_id};

    # this means we show the page for an rtv shipment not the search
    my $refresh_details = $handler->{data}{rtv_shipment_id} =~ m{\A\d+\z}xms;

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    if ( $handler->{data}{rtv_shipment_id} !~ m{\A\d+\z}xms
        && !( $handler->{param_of}{'submit_add_note'} )
        && !( $handler->{param_of}{'submit_rtv_shipment_detail_result'} )
    ) {

        ## display RTV shipment list

        $handler->{data}{tt_process_block}    = 'rtv_shipment_list';

        ## fetch list of rma_request designers and seasons
        $handler->{data}{rma_request_designers} = list_rma_request_designers( { dbh => $dbh} );
        $handler->{data}{rma_request_seasons}   = list_rma_request_seasons( { dbh => $dbh} );
        $handler->{data}{channels} = [
            $schema->resultset('Public::Channel')->enabled_channels->all
        ];

        # Strip order_by and asc_desc from search_uri params
        my %search_params = %{$handler->{param_of}};
        my @sort_keys = qw{order_by asc_desc};
        @{$handler->{data}{columnsort}}{@sort_keys} = delete @search_params{@sort_keys};
        my $uri = URI->new($handler->path);
        $uri->query_form(%search_params);

        # Store the last search in the session, so we can return to it
        # NOTE: This will behave oddly if users perform searches using multiple
        # tabs, and it's kind of the wrong thing to do, but the users like it,
        # and it's a quick win
        $handler->session_stash->{last_dispatched_rtv_search_params}
            = \%{$handler->{param_of}};

        # Pass search parameters (for auto-filling form) and URI (for ordering
        # cols) back to template
        $handler->{data}{search_params} = \%search_params;
        $handler->{data}{search_uri} = $uri;

        ## fetch list of RTV shipments, based on specified search criteria
        my $rtv_shipment_list_ref = _list_rtv_shipments_filtered({
            schema          => $schema,
            rest_ref        => \%search_params,
            columnsort      => $handler->{data}{columnsort},
        });

        # Redirect to shipment page if we only have one result
        return $handler->redirect_to(
            join q{?}, $handler->path, "rtv_shipment_id=$rtv_shipment_list_ref->[0]{rtv_shipment_id}"
        ) if ( grep { $_ && ref $_ eq 'ARRAY' && @$_ && @$_ == 1 } $rtv_shipment_list_ref );

        $handler->{data}{rtv_shipment_list} = $rtv_shipment_list_ref;
    }
    elsif ( $handler->{param_of}{'submit_add_note'} ) {

        $refresh_details = 1;

        ## prepend reference (rtv_shipment_id)
        my $rma_request_note = "[RTVS-$handler->{data}{rtv_shipment_id}]: " . $handler->{param_of}{txta_rma_request_note};

        eval {
            $schema->txn_do(sub{
                ## Add RMA Request note entry
                insert_rma_request_note({
                    dbh             => $dbh,
                    rma_request_id  => $handler->{data}{rma_request_id},
                    operator_id     => $handler->{data}{operator_id},
                    note            => $rma_request_note,
                });
            });
        };
        if ($@) {
            xt_warn($@);
        }
    }
    elsif ( $handler->{param_of}{'submit_rtv_shipment_detail_result'} ) {

        $refresh_details = 1;

        my $rtv_shipment_detail_id = $handler->{param_of}{detail_id};

        my %rtv_shipment_detail_result_type_id = (
            credited        => $RTV_CONSTANTS_REF->{RTV_SHIP_DET_RESULT_TYPE_CREDITED},
            repaired        => $RTV_CONSTANTS_REF->{RTV_SHIP_DET_RESULT_TYPE_REPAIRED},
            replaced        => $RTV_CONSTANTS_REF->{RTV_SHIP_DET_RESULT_TYPE_REPLACED},
            dead            => $RTV_CONSTANTS_REF->{RTV_SHIP_DET_RESULT_TYPE_DEAD},
            stock_swapped   => $RTV_CONSTANTS_REF->{RTV_SHIP_DET_RESULT_TYPE_STOCK_SWAPPED},

        );
        lock_hash(%rtv_shipment_detail_result_type_id);


        my %insert_data   = ();
        my $total_quantity_entered = 0;

        eval {
            RESULT_TYPE:
            foreach my $result_type ( keys %rtv_shipment_detail_result_type_id ) {

                my $qty_field_name  = $result_type . '_qty_' . $rtv_shipment_detail_id;
                my $ref_field_name  = $result_type . '_ref_' . $rtv_shipment_detail_id;
                my $type_id         = $rtv_shipment_detail_result_type_id{$result_type};

                if ( $handler->{param_of}{$qty_field_name} !~ m{\A\d+\z}xms ) {
                    die "Invalid $qty_field_name ($handler->{param_of}{$qty_field_name})";
                }
                next RESULT_TYPE unless ( $handler->{param_of}{$qty_field_name} > 0 );

                $total_quantity_entered += $handler->{param_of}{$qty_field_name};

                $insert_data{$type_id}{quantity}    = $handler->{param_of}{$qty_field_name};
                $insert_data{$type_id}{reference}   = $handler->{param_of}{$ref_field_name};

            } ## END foreach RESULT_TYPE


            ## re-fetch shipment details
            my $rtv_shipment_details_ref
                = list_rtv_shipment_details({
                    dbh                 => $dbh,
                    type                => 'rtv_shipment_detail_id',
                    id                  => $rtv_shipment_detail_id,
                    get_image_names     => 1,
                    get_detail_results  => 1,
            });
            my $variant_id                  = $rtv_shipment_details_ref->[0]{variant_id};
            my $delivery_item_id            = $rtv_shipment_details_ref->[0]{delivery_item_id};
            my $rtv_shipment_detail_qty     = $rtv_shipment_details_ref->[0]{rtv_shipment_detail_quantity};
            my $result_total_unknown        = $rtv_shipment_details_ref->[0]{result_total_unknown};
            my $result_total_credited       = $rtv_shipment_details_ref->[0]{result_total_credited};
            my $result_total_repaired       = $rtv_shipment_details_ref->[0]{result_total_repaired};
            my $result_total_replaced       = $rtv_shipment_details_ref->[0]{result_total_replaced};
            my $result_total_dead           = $rtv_shipment_details_ref->[0]{result_total_dead};
            my $result_total_stock_swapped  = $rtv_shipment_details_ref->[0]{result_total_stock_swapped};
            my $rtv_shipment_detail_result_notes;

            my $total_quantity_outstanding
                = ($rtv_shipment_detail_qty
                - ($result_total_unknown + $result_total_credited + $result_total_repaired + $result_total_replaced + $result_total_dead + $result_total_stock_swapped));


            if ( $total_quantity_entered > $total_quantity_outstanding ) {
                die "Quantity mismatch!  Total quantity entered ($total_quantity_entered) exceeds total quantity outstanding ($total_quantity_outstanding)";
            }

            $schema->txn_do(sub{
                foreach my $type_id ( sort keys %insert_data ) {

                    ## perform appropriate result action
                    if ( $type_id == $rtv_shipment_detail_result_type_id{credited} ) {

                        ##TODO: Inform Finance team.  Transfer data to Sun (journal import) [ this will probably be implemented as a scheduled task ]

                    }
                    elsif ( $type_id == $rtv_shipment_detail_result_type_id{stock_swapped} ) {

                        ##TODO

                    }
                    elsif ( $type_id == $rtv_shipment_detail_result_type_id{repaired} ) {

                        ##TODO: Create re-shipment to Customer

                    }
                    elsif ( $type_id == $rtv_shipment_detail_result_type_id{replaced} ) {

                        my $quantity = $insert_data{$type_id}{quantity};

                        ## create_rtv_replacement_stock_order
                        my $stock_order_item_id
                            = create_rtv_replacement_stock_order({
                                    dbh         => $dbh,
                                    variant_id  => $variant_id,
                                    quantity    => $quantity,
                            });

                        $rtv_shipment_detail_result_notes = "stock_order_item_id: $stock_order_item_id";

                    }
                    elsif ( $type_id == $rtv_shipment_detail_result_type_id{dead} ) {

                        ## add to putaway list - dead stock
                        my $quantity            = $insert_data{$type_id}{quantity};

                        my $group = 0;

                        my $stock_process_id
                            = create_rtv_stock_process({
                                dbh                     => $dbh,
                                stock_process_type_id   => $STOCK_PROCESS_TYPE__DEAD,
                                delivery_item_id        => $delivery_item_id,
                                quantity                => $quantity,
                                process_group_ref       => \$group,
                                stock_process_status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
                                originating_path        => $handler->path,
                            });

                        {
                            my $sp = $schema->resultset('Public::StockProcess')->find($stock_process_id);
                            $handler->msg_factory->transform_and_send('XT::DC::Messaging::Producer::WMS::PreAdvice',{
                                sp => $sp,
                            });
                        }

                        ## print stock sheet
                        my $delivery_id = get_parent_id({ dbh => $dbh, type => 'delivery_item', id => $delivery_item_id } );

                        my $document = XTracker::Document::RTVStockSheet->new(
                            group_id        => $group,
                            document_type   => 'dead',
                            origin          => 'dispatched_rtv'
                        );

                        my $channel_id = $document->delivery->stock_order->product->get_product_channel->channel->id;

                        my $print_location = get_rtv_print_location($schema, $channel_id);

                        $document->print_at_location($print_location);

                        $rtv_shipment_detail_result_notes = "stock_process_id: $stock_process_id (Putaway list, type 'Dead')";

                    }
                    else {
                        die "Invalid type_id ($type_id)!"
                    }


                    ## log result
                    my $rtv_shipment_detail_result_id
                        = insert_rtv_shipment_detail_result({
                                dbh                     => $dbh,
                                rtv_shipment_detail_id  => $rtv_shipment_detail_id,
                                type_id                 => $type_id,
                                quantity                => $insert_data{$type_id}{quantity},
                                reference               => $insert_data{$type_id}{reference},
                                notes                   => $rtv_shipment_detail_result_notes,
                                operator_id             => $handler->{data}{operator_id},
                        });

                } ## END foreach
            });
        };
        if ($@) {
            xt_warn($@);
        }
    } ## END if


    if ( $refresh_details ) {

        $handler->{data}{sidenav} = [ { "None" => [{
            title => 'New Search',
            url => $handler->path,
        }] }];
        # Set a back to search link retrieved frmo the session if we have one
        if ( $handler->session_stash->{last_dispatched_rtv_search_params} ) {
            my $uri = URI->new($handler->path);
            $uri->query_form($handler->session_stash->{last_dispatched_rtv_search_params});
            push @{$handler->{data}{sidenav}[0]{None}}, {
                title => 'Back&nbsp;to&nbsp;List',
                url   => $uri,
            };
        }

        ## Drilldown to rtv shipment details

        $handler->{data}{tt_process_block}  = 'rtv_shipment';

        ### fetch RTV shipment details
        my $rtv_shipment_details_ref
            = list_rtv_shipment_details({
                    dbh                 => $dbh,
                    type                => 'rtv_shipment_id',
                    id                  => $handler->{data}{rtv_shipment_id},
                    get_image_names     => 1,
                    get_detail_results  => 1,
            });
        $handler->{data}{rtv_shipment_details}          = $rtv_shipment_details_ref;
        $handler->{data}{rtv_shipment_result_details}   = list_rtv_shipment_result_details( { dbh => $dbh, rtv_shipment_id => $handler->{data}{rtv_shipment_id} } );

        $handler->{data}{rma_request_id}  = $rtv_shipment_details_ref->[0]{rma_request_id};

        if ( scalar @{$rtv_shipment_details_ref} ) {
            $handler->{data}{subsubsection} = "Details - RTV Shipment $rtv_shipment_details_ref->[0]{rtv_shipment_id}";
        }

        ### fetch comment log entries
        $handler->{data}{rma_request_notes} = list_rma_request_notes( { dbh => $dbh, rma_request_id => $handler->{data}{rma_request_id} } );

                $handler->{data}{sales_channel} = $rtv_shipment_details_ref->[0]{sales_channel};

    } # END if ( $refresh_details )

    return $handler->process_template;
} ## END sub handler


sub _list_rtv_shipments_filtered {

    my ($arg_ref)           = @_;
    my $schema              = $arg_ref->{schema};
    my $rest_ref            = $arg_ref->{rest_ref};
    my $columnsort          = $arg_ref->{columnsort};

    return unless $rest_ref->{search_select};

    my %display_name = (
        select_designer_id     => 'Designer',
        select_season_id       => 'Season',
        select_sku             => 'SKU',
        select_airwaybill      => 'Airwaybill',
        select_rtv_shipment_id => 'RTV Shipment',
        select_rma_number      => 'RMA',
        select_channel_id      => 'Channel',
    );
    # We always set the status
    my $params = { status_id => $RTV_SHIPMENT_STATUS__DISPATCHED };
    # Build our list of parameters to search for
    my %param_map = (
        select_airwaybill      => sub { $params->{airway_bill} = $_[0]; },
        select_rma_number      => sub { $params->{rma_number} = $_[0]; },
        select_designer_id     => sub {
            $params->{designer_id} = $_[0] if is_valid_format({ value => $_[0], format => 'id' });
        },
        select_season_id       => sub {
            $params->{season_id} = $_[0] if is_valid_format({ value => $_[0], format => 'id' });
        },
        select_rtv_shipment_id => sub {
            $params->{rtv_shipment_id} = $_[0] if is_valid_format({ value => $_[0], format => 'id' });
        },
        select_channel_id      => sub {
            $params->{channel_id} = $_[0] if is_valid_format({ value => $_[0], format => 'id' });
        },
        select_sku             => sub {
            if ( is_valid_format({ value => $_[0], format => 'sku' }) ) {
                # We should remember that one SKU can map > 1 variant_id
                $params->{variant_id} = [ $schema->resultset('Public::Variant')
                                                 ->search_by_sku($_[0])
                                                 ->get_column('id')
                                                 ->all ];
                $params->{variant_id} = undef unless @{$params->{variant_id}};
            }
            elsif ( is_valid_format({ value => $_[0], format => 'int_positive' }) ) {
                $params->{product_id} = $_[0];
            }
        },
    );
    while ( my ( $name, $subref ) = each %param_map ) {
        # Strip leading/trailing whitespace
        ( my $val = ($rest_ref->{$name}//q{}) ) =~ s{^\s*}{}; $val =~ s{\s*$}{};
        next unless $val;
        next if $subref->($val);
        xt_warn("Invalid input for $display_name{$name}");
        return;
    }

    my $rtv_shipment_list_ref = list_rtv_shipments({
        dbh                 => $schema->storage->dbh,
        params              => $params,
        columnsort          => $columnsort,
    });

    return $rtv_shipment_list_ref;
}

1;
