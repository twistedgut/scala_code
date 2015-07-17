package XTracker::Stock::Actions::RTV::SetRMA;

use strict;
use warnings;

use Hash::Util                          qw(lock_hash);

use XTracker::Handler;
use XTracker::Utilities         qw( :edit :string );
use XTracker::Constants::FromDB qw(:rma_request_status :rma_request_detail_status :stock_process_type :stock_process_status);
use XTracker::Database::RTV     qw(:rma_request :rtv_shipment :rtv_document :validate :rtv_stock update_rtv_status list_countries get_operator_details get_parent_id is_nonfaulty create_rtv_stock_process get_rtv_print_location);
use XTracker::Database::StockProcess qw( :iws );
use XTracker::Error;
use XTracker::Document::RTVStockSheet;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    my $RTV_CONSTANTS_REF = {
        RMA_STAT_NEW            => $RMA_REQUEST_STATUS__NEW,
        RMA_STAT_REQUESTED      => $RMA_REQUEST_STATUS__RMA_REQUESTED,
        RMA_STAT_RECEIVED       => $RMA_REQUEST_STATUS__RMA_RECEIVED,
        RMA_STAT_PROCESSING     => $RMA_REQUEST_STATUS__RTV_PROCESSING,
        RMA_DET_STAT_NEW        => $RMA_REQUEST_DETAIL_STATUS__NEW,
        RMA_DET_STAT_DEAD       => $RMA_REQUEST_DETAIL_STATUS__SENT_TO_DEAD_STOCK,
        RMA_DET_STAT_MAIN       => $RMA_REQUEST_DETAIL_STATUS__SENT_TO_MAIN_STOCK,
    };
    lock_hash(%$RTV_CONSTANTS_REF);

    my $rtv_shipment_id = undef;

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;
    my $operator_details_ref = get_operator_details( { dbh => $dbh, operator_id => $handler->{data}{operator_id} } );

    # grab search params from url so we can redirect back to same list
    my $rma_request_id  = $handler->{param_of}{rma_request_id};
    my $channel_id      = $handler->{param_of}{channel_id};

    my $redirect_url    = '/RTV/ListRMA?rma_request_id='.$rma_request_id;

    eval {
        my $guard = $schema->txn_scope_guard;

        # add note to RMA
        if ( $handler->{param_of}{'submit_add_note'} ) {

            insert_rma_request_note({
                dbh             => $dbh,
                rma_request_id  => $rma_request_id,
                operator_id     => $handler->{data}{operator_id},
                note            => trim( $handler->{param_of}{txta_rma_request_note} ),
            });

            xt_success("Note added successfully.");
        }
        # update header rma info
        elsif ( $handler->{param_of}{'submit_update_header'} ) {

            _update_rma_request_header_data({
                dbh                 => $dbh,
                rma_request_id      => $rma_request_id,
                data_ref            => $handler->{param_of},
                rtv_constants_ref   => $RTV_CONSTANTS_REF,
                operator_id         => $handler->{data}{operator_id},
            });

            xt_success("RMA Details updated successfully.");

        }
        # send out RMA email
        elsif ( $handler->{param_of}{'submit_send_rma_email'} ) {

            ## send the email
            my $mail_sent = send_rma_request_email({
                to              => $handler->{param_of}{txt_rma_email_to},
                from            => $operator_details_ref->{email_address},
                cc              => $handler->{param_of}{txt_rma_email_cc},
                bcc             => $handler->{param_of}{txt_rma_email_bcc} ||
                    $operator_details_ref->{email_address},
                subject         => $handler->{param_of}{txt_rma_email_subject},
                message         => $handler->{param_of}{txta_rma_email_message},
                attachment_name => $handler->{param_of}{email_attachment_name},
            });

            if ($mail_sent) {
                ## update rma_request_status
                update_rtv_status({
                    dbh         => $dbh,
                    entity      => 'rma_request',
                    type        => 'rma_request_id',
                    id          => $rma_request_id,
                    status_id   => $RTV_CONSTANTS_REF->{RMA_STAT_REQUESTED},
                    operator_id => $handler->{data}{operator_id},
                });
            } ## END if ($mail_sent)

            xt_success("Email sent successfully.");

        }
        # create RTV shipment for RMA
        elsif ( $handler->{param_of}{'submit_create_rtv_shipment'} ) {

            # update header data if necessary
            _update_rma_request_header_data({
                dbh                 => $dbh,
                rma_request_id      => $rma_request_id,
                data_ref            => $handler->{param_of},
                rtv_constants_ref   => $RTV_CONSTANTS_REF,
                operator_id         => $handler->{data}{operator_id},
            });

            # Add RMA Request note entry if necessary
            insert_rma_request_note({
                dbh             => $dbh,
                rma_request_id  => $rma_request_id,
                operator_id     => $handler->{data}{operator_id},
                note            => trim( $handler->{param_of}{txta_rma_request_note} ),
            });

            ## create lists of id's for items to RTV and fire onto Dead stock
            my @rma_request_detail_ids_rtv      = map { m/\Artv_(\d+)\z/xms } values %{$handler->{param_of}};
            my @rma_request_detail_ids_dead     = map { m/\Adead_(\d+)\z/xms } values %{$handler->{param_of}};
            my @rma_request_detail_ids_main     = map { m/\Amain_(\d+)\z/xms } values %{$handler->{param_of}};
            my @rma_request_detail_ids_noaction = map { m/\Anoaction_(\d+)\z/xms } values %{$handler->{param_of}};


            # process RTV items
            if ( scalar @rma_request_detail_ids_rtv ) {

                # insert new rtv_address, if necessary
                if ( $handler->{param_of}{ddl_designer_address} !~ m{\A\d+\z}xms ) {

                    my $contact_name = $handler->{param_of}{txt_contact_name};

                    die 'No address was specified' unless ( trim($handler->{param_of}{txt_address_one}) && trim($handler->{param_of}{txt_town_city}) );

                    my $address_ref = {
                        address_line_1 => $handler->{param_of}{txt_address_one},
                        address_line_2 => $handler->{param_of}{txt_address_two},
                        address_line_3 => $handler->{param_of}{txt_address_three},
                        town_city      => $handler->{param_of}{txt_town_city},
                        region_county  => $handler->{param_of}{txt_region_county},
                        postcode_zip   => $handler->{param_of}{txt_postcode_zip},
                        country        => $handler->{param_of}{ddl_country},
                    };

                    $handler->{param_of}{ddl_designer_address} = insert_designer_address({
                            dbh             => $dbh,
                            designer_id     => $handler->{param_of}{designer_id},
                            contact_name    => $contact_name,
                            address_ref     => $address_ref,
                    });

                } ## END if


                ## insert new rtv carrier, if necessary
                if ( $handler->{param_of}{ddl_designer_carrier} !~ m{\A\d+\z}xms ) {

                    my $ddl_carrier_name_new    = trim( $handler->{param_of}{ddl_carrier_name_new} );
                    my $txt_carrier_name_new    = trim( $handler->{param_of}{txt_carrier_name_new} );
                    my $txt_carrier_account_ref = trim( $handler->{param_of}{txt_carrier_account_ref} );

                    my $carrier_name_new = $ddl_carrier_name_new =~ m{\A\w+[\w\s]*\w+\z}xms ? $ddl_carrier_name_new : $txt_carrier_name_new;

                    $handler->{param_of}{ddl_designer_carrier} = insert_designer_carrier({
                            dbh         => $dbh,
                            designer_id => $handler->{param_of}{designer_id},
                            name        => $carrier_name_new,
                            account_ref => $txt_carrier_account_ref,
                    });

                } ## END if


                ## create RTV shipment
                my $head_ref = {
                    rma_request_id          => $rma_request_id,
                    channel_id              => $channel_id,
                    designer_rtv_carrier_id => $handler->{param_of}{ddl_designer_carrier},
                    designer_rtv_address_id => $handler->{param_of}{ddl_designer_address},
                };

                my %dets_ref    = ();
                $dets_ref{$_}   = () foreach @rma_request_detail_ids_rtv;

                $rtv_shipment_id
                    = create_rtv_shipment({
                        dbh         => $dbh,
                        head_ref    => $head_ref,
                        dets_ref    => \%dets_ref,
                        operator_id => $handler->{data}{operator_id},
                    });


            } ## END if ( scalar @rma_request_detail_ids_rtv )


            ## process dead/main items
            if ( scalar @rma_request_detail_ids_dead || scalar @rma_request_detail_ids_main ) {

                my $rma_request_details_ref = list_rma_request_details( { dbh => $dbh, type => 'rma_request_id', id => $rma_request_id, results_as_hash => 1 } );

                ## dead
                foreach my $rma_request_detail_id (@rma_request_detail_ids_dead) {

                    my $delivery_item_id    = $rma_request_details_ref->{$rma_request_detail_id}{delivery_item_id};
                    my $quantity            = $rma_request_details_ref->{$rma_request_detail_id}{rma_request_detail_quantity};

                    ## fire onto the dead stock putaway list
                    my $sp_group_dead = 0;

                    create_rtv_stock_process({
                        dbh                     => $dbh,
                        stock_process_type_id   => $STOCK_PROCESS_TYPE__DEAD,
                        delivery_item_id        => $delivery_item_id,
                        quantity                => $quantity,
                        process_group_ref       => \$sp_group_dead,
                        stock_process_status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
                        originating_path        => $r->parsed_uri->path,
                    });

                    ## move RTV stock out
                    move_rtv_stock_out({
                        dbh             => $dbh,
                        rtv_stock_type  => 'RTV Process',
                        type            => 'rma_request_detail_id',
                        id              => $rma_request_detail_id,
                    });

                    ## update rma_request_detail status
                    update_rtv_status({
                        dbh         => $dbh,
                        entity      => 'rma_request_detail',
                        type        => 'rma_request_detail_id',
                        id          => $rma_request_detail_id,
                        status_id   => $RTV_CONSTANTS_REF->{RMA_DET_STAT_DEAD},
                        operator_id => $handler->{data}{operator_id},
                    });

                    send_pre_advice($handler->msg_factory,
                                    $schema,
                                    $sp_group_dead,
                                    $STOCK_PROCESS_TYPE__DEAD,
                                    $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED);

                    ## print stock sheet

                    my $delivery_id = get_parent_id({ dbh => $dbh, type => 'delivery_item', id => $delivery_item_id } );

                    my $document = XTracker::Document::RTVStockSheet->new(
                        group_id        => $sp_group_dead,
                        document_type   => 'dead',
                        origin          => 'rma_request'
                    );

                    my $print_location = get_rtv_print_location($schema, $channel_id);

                    $document->print_at_location($print_location);

                } ## END foreach


                ## main
                foreach my $rma_request_detail_id (@rma_request_detail_ids_main) {

                    my $delivery_item_id    = $rma_request_details_ref->{$rma_request_detail_id}{delivery_item_id};
                    my $quantity            = $rma_request_details_ref->{$rma_request_detail_id}{rma_request_detail_quantity};

                    ## fire onto the dead stock putaway list
                    my $sp_group_main = 0;

                    create_rtv_stock_process({
                        dbh                     => $dbh,
                        stock_process_type_id   => $STOCK_PROCESS_TYPE__RTV_FIXED,
                        delivery_item_id        => $delivery_item_id,
                        quantity                => $quantity,
                        process_group_ref       => \$sp_group_main,
                        stock_process_status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
                        originating_path        => $r->parsed_uri->path,
                    });

                    ## move RTV stock out
                    move_rtv_stock_out({
                        dbh             => $dbh,
                        rtv_stock_type  => 'RTV Process',
                        type            => 'rma_request_detail_id',
                        id              => $rma_request_detail_id,
                    });

                    ## update rma_request_detail status
                    update_rtv_status({
                        dbh         => $dbh,
                        entity      => 'rma_request_detail',
                        type        => 'rma_request_detail_id',
                        id          => $rma_request_detail_id,
                        status_id   => $RTV_CONSTANTS_REF->{RMA_DET_STAT_MAIN},
                        operator_id => $handler->{data}{operator_id},
                    });

                    send_pre_advice($handler->msg_factory,
                                    $schema,
                                    $sp_group_main,
                                    $STOCK_PROCESS_TYPE__RTV_FIXED,
                                    $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED);

                    ## print stock sheet

                    my $delivery_id = get_parent_id({ dbh => $dbh, type => 'delivery_item', id => $delivery_item_id } );

                    my $document = XTracker::Document::RTVStockSheet->new(
                        group_id        => $sp_group_main,
                        document_type   => 'main',
                        origin          => 'rma_request'
                    );

                    my $print_location = get_rtv_print_location($schema, $channel_id);

                    $document->print_at_location($print_location);

                } ## END foreach


            } ## END if

            xt_success('RTV shipment created successfully.');
            $redirect_url   = '/RTV/ListRTV/SetRTVShipment?'
                              . (defined $rtv_shipment_id ? "rtv_shipment_id=${rtv_shipment_id}&" : '')
                              . 'submit_print_rtv_picklist=1';

        } ## END if


        $guard->commit();

    };

    if ($@) {
        xt_warn("An error occured:<br />$@");
    }

    return $handler->redirect_to( $redirect_url );
}

sub _update_rma_request_header_data {
    my ($arg_ref)           = @_;

    my $dbh                 = $arg_ref->{dbh};
    my $rma_request_id      = $arg_ref->{rma_request_id};
    my $data_ref            = $arg_ref->{data_ref};
    my $RTV_CONSTANTS_REF   = $arg_ref->{rtv_constants_ref};
    my $operator_id         = $arg_ref->{operator_id};

    my %fields  = ();
    $fields{date_followup}  = $data_ref->{ddl_date_followup_datestring} if exists $data_ref->{ddl_date_followup_datestring};
    $fields{comments}       = trim( $data_ref->{txta_comments} ) if exists $data_ref->{txta_comments};

    if ( exists $data_ref->{txt_rma_number} && length( trim( $data_ref->{txt_rma_number} ) ) > 0 ) {

        $fields{rma_number} = trim( $data_ref->{txt_rma_number} );

        ## Update rma_request status
        update_rtv_status({
            dbh         => $dbh,
            entity      => 'rma_request',
            type        => 'rma_request_id',
            id          => $rma_request_id,
            status_id   => $RTV_CONSTANTS_REF->{RMA_STAT_RECEIVED},
            operator_id => $operator_id,
        });

    }

    ## Update rma_request
    update_rma_request({
        dbh             => $dbh,
        rma_request_id  => $rma_request_id,
        fields_ref      => \%fields,
    });

    return;

} ## END sub _update_rma_request_header_data

1;
