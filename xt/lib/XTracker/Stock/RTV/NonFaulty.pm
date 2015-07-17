package XTracker::Stock::RTV::NonFaulty;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use Plack::App::FakeApache1::Constants qw(:common);
use Hash::Util                          qw(lock_hash);
use JSON                                qw(to_json);

use XTracker::Handler;
use XTracker::Constants::FromDB         qw(:rma_request_status :rma_request_detail_status :pws_action);
use XTracker::Database                  qw(:common);
use XTracker::Database::RTV             qw(:nonfaulty :rtv_stock get_operator_details list_rma_request_detail_types create_rma_request);
use XTracker::Database::Channel         qw( get_channel get_channels );
use XTracker::Session;
use XTracker::Utilities                 qw(:edit :string );
use XTracker::WebContent::StockManagement;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    my $regex_txta_product_ids  = qr{\A\s*((?:\d+\s*,+\s*)*\d+)[\s,]*\z}xms;

    $handler->{data}{section} = 'RTV';
    $handler->{data}{subsection}            = 'Non Faulty';
    $handler->{data}{subsubsection}         = '';
    $handler->{data}{content}               = 'rtv/non_faulty.tt';
    $handler->{data}{tt_process_block}      = undef;
    $handler->{data}{filter_msgs}           = [];
    $handler->{data}{operator_details}      = get_operator_details( { dbh => $handler->{dbh}, operator_id => $handler->{data}{operator_id} } );
    $handler->{data}{timestring}            = time;
    $handler->{data}{posted_product_ids}    = defined $handler->{param_of}{txta_product_ids} ? $handler->{param_of}{txta_product_ids} : '';
    $handler->{data}{channels}              = get_channels( $handler->{dbh} );


    if ( $handler->{param_of}{submit_search_pids} ) {

        eval {

            if ( $handler->{data}{posted_product_ids} =~ $regex_txta_product_ids ) {

                $handler->{data}{channel_id} = defined $handler->{param_of}{channel_id} ? $handler->{param_of}{channel_id} : die 'No channel id defined';

                my @product_ids = grep { m{\A\s*\d+\s*\z}x } split /,/, $1;
                $_ = trim($_) foreach (@product_ids);

                $handler->{data}{nonfaulty_stock}     = list_nonfaulty_stock( { dbh => $handler->{dbh}, product_ids => \@product_ids, channel_id => $handler->{data}{channel_id} } );
                $handler->{data}{nonfaulty_allocated} = list_nonfaulty_allocated( { dbh => $handler->{dbh}, product_ids => \@product_ids, channel_id => $handler->{data}{channel_id} } );

                ## list PIDs which were submitted but returned no records
                my @invalid_pids = ();
                SUBMITTED_PID:
                foreach my $submitted_pid (@product_ids) {
                    NONFAULTY_ROW:
                    foreach my $nonfaulty_row_ref (@{$handler->{data}{nonfaulty_stock}}) {
                        next SUBMITTED_PID if $submitted_pid == $nonfaulty_row_ref->{product_id};
                    }
                    push @invalid_pids, $submitted_pid;
                }

                $handler->{data}{error_msg} .= "The folowing PIDs are not valid: @{[join(', ', @invalid_pids)]}" if scalar @invalid_pids;

                $handler->{data}{tt_process_block}    = 'frm_select_items';
                $handler->{data}{subsubsection}       = 'Create Request';
                $handler->{data}{request_detail_type} = list_rma_request_detail_types( { dbh => $handler->{dbh}, category => 'nonfaulty' } );

            }
            else {
                $handler->{data}{error_msg}         .= "Please ensure that you enter a comma-seperated list of Product IDs";
                $handler->{data}{tt_process_block}  = 'frm_search_pids';
                $handler->{data}{subsubsection}     = 'PID Search';
            }

        };
        if ($@) {
            $handler->{data}{error_msg} .= $@;
            $handler->{data}{tt_process_block}  = 'frm_search_pids';
            $handler->{data}{subsubsection}     = 'PID Search';
        }

    }
    elsif ( $handler->{param_of}{submit_create_rma_request} ) {

        my @designer_ids_transfer_succeeded = ();
        my $rma_request_dets_ref;

        my $channel_id      = defined $handler->{param_of}{channel_id} ? $handler->{param_of}{channel_id} : die 'No channel id defined';

        my $dbh_trans = get_database_handle( { name => 'xtracker', type => 'transaction' } );

        eval {

            # get channel info
            my $channel_data    = get_channel($dbh_trans, $channel_id);

            ## package RMA Request data by designer_id
            my %rma_request = ();
            foreach my $field ( keys %{ $handler->{param_of} } ) {
                if ( $field =~ m/^include_(\d+)/ ) {
                    my $quantity_id = $1;
                    my %data_ref = ();

                    $data_ref{sku}                  = $handler->{param_of}{'sku_'.$quantity_id};
                    $data_ref{variant_id}           = $handler->{param_of}{'variant_id_'.$quantity_id};
                    $data_ref{location_id}          = $handler->{param_of}{'location_id_'.$quantity_id};
                    $data_ref{request_quantity}     = $handler->{param_of}{'request_quantity_'.$quantity_id};
                    $data_ref{request_detail_type}  = $handler->{param_of}{'request_detail_type_'.$quantity_id};

                    push @{ $rma_request{ $handler->{param_of}{'designer_id_'.$quantity_id} } }, \%data_ref;
                }
            }


            foreach my $designer_id ( keys %rma_request ) {

                eval {

                    ## transfer nonfaulty stock
                    foreach my $row_ref ( @{ $rma_request{$designer_id} } ) {

                        my $rtv_quantity_id
                            = transfer_nonfaulty_stock({
                                dbh                 => $dbh_trans,
                                variant_id          => $row_ref->{variant_id},
                                location_id_from    => $row_ref->{location_id},
                                quantity            => $row_ref->{request_quantity},
                                operator_id         => $handler->{data}{operator_id},
                                channel_id          => $channel_id,
                            });

                        $rma_request_dets_ref->{$designer_id}{$rtv_quantity_id}{type_id} = $row_ref->{request_detail_type};

                    } ## END foreach my $row_ref


                    ## update website stock if transfer succeeded for all rows
                    if ( $dbh_trans->commit ) {

                        ## update website stock
                        my $stock_manager
                            = XTracker::WebContent::StockManagement->new_stock_manager({
                            schema      => get_schema_using_dbh( $handler->{dbh}, 'xtracker_schema' ),
                            channel_id  => $channel_id,
                        });

                        foreach my $row_ref ( @{ $rma_request{$designer_id} } ) {

                            eval {

                                    $stock_manager->stock_update(
                                        quantity_change => -$row_ref->{request_quantity},
                                        variant_id      => $row_ref->{variant_id},
                                        skip_non_live   => 1,
                                        pws_action_id   => $PWS_ACTION__RTV_NON_DASH_FAULTY,
                                        operator_id     => $handler->{data}{operator_id},
                                    );

                            };
                            if ($@) {
                                $stock_manager->rollback;
                                $handler->{data}{error_msg} .= "Failed to update website stock level for sku $row_ref->{sku}: $@";
                            }

                        }

                        $stock_manager->disconnect;

                        push @designer_ids_transfer_succeeded, $designer_id;

                    }

                };
                if ($@) {
                    $dbh_trans->rollback();
                    $handler->{data}{error_msg} .= "\n$@";
                }

            } ## END foreach my $designer_id

        };
        if ($@) {
            $handler->{data}{error_msg} .= "\n$@";
        }


        ## create RMA Requests (non-faulty)
        my @created_rma_request_ids = ();
        foreach my $designer_id ( @designer_ids_transfer_succeeded ) {

            eval {
                my $rma_request_id = create_rma_request({
                    dbh         => $dbh_trans,
                    head_ref    => {
                        operator_id => $handler->{data}{operator_id},
                        comments    => 'Non-Faulty',
                        channel_id  => $channel_id },
                        dets_ref    => $rma_request_dets_ref->{$designer_id},
                    }
                );

                if ( $dbh_trans->commit ) {
                    push @created_rma_request_ids, $rma_request_id;
                }

            };
            if ($@) {
                $dbh_trans->rollback();
                $handler->{data}{error_msg} .= "\n$@";
            }

        } ## END foreach my $designer_id


        $handler->{data}{tt_process_block}    = 'rma_requests_created';
        $handler->{data}{subsubsection}       = 'RMA Requests Created';
        $handler->{data}{rma_request_ids}     = \@created_rma_request_ids;

    }
    else {
        $handler->{data}{tt_process_block}    = 'frm_search_pids';
        $handler->{data}{subsubsection}       = 'PID Search';
    }


    $handler->process_template( undef );

    return OK;
} ## END sub handler




1;

__END__
