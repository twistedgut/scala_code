package XTracker::Stock::RTV::PackRTV;

use strict;
use warnings;
use Carp;

use XTracker::Handler;
use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Constants::FromDB qw(:rtv_shipment_status :rtv_shipment_detail_status :authorisation_level);
use XTracker::Database::RTV     qw(:rtv_stock :rtv_shipment :rtv_shipment_pack :validate get_rtv_status update_rtv_status is_nonfaulty);
use XTracker::Utilities         qw(:edit :string);
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}               = 'RTV';
    $handler->{data}{subsection}            = 'Shipment Pack';
    $handler->{data}{subsubsection}         = '';
    $handler->{data}{content}               = 'rtv/pack_rtv.tt';
    $handler->{data}{tt_process_block}      = 'pack_rtv';
    $handler->{data}{operator_auth_level}   = $handler->{data}{auth_level};
    $handler->{data}{AUTH_LEVEL_MANAGER}    = $AUTHORISATION_LEVEL__MANAGER;

    $handler->{data}{rtv_shipment_id}       = defined $handler->{param_of}{rtv_shipment_id} ? $handler->{param_of}{rtv_shipment_id}  : '';

    # remove 'RTVS-' prefix if necessary (i.e. for scanned input)
    $handler->{data}{rtv_shipment_id}    = $handler->{data}{rtv_shipment_id} =~ m{\ARTVS-(\d+)\z}xms ? $1 : $handler->{data}{rtv_shipment_id};

    $handler->{data}{txt_entry} = defined $handler->{param_of}{txt_entry}    ? $handler->{param_of}{txt_entry}    : '';
    $handler->{data}{txt_entry} = trim($handler->{data}{txt_entry});

    my $fetch_list  = $handler->{data}{rtv_shipment_id}  =~ m{\A\d+\z}xms            ? 1
                    : $handler->{param_of}{submit_pack_rtv_entry}     ? 1 ## submit - scanned entry
                    : $handler->{param_of}{submit_pack_auto}          ? 1 ## submit - auto-pack
                    : $handler->{param_of}{submit_pack_rtv_commit}    ? 0 ## submit - commit pack
                    : $handler->{param_of}{submit_pack_rtv_cancel}    ? 0 ## submit - cancel pack
                    :                                                 0
                    ;

    my $status_ref;


    my $schema = $handler->schema;
    if ( $handler->{param_of}{submit_pack_rtv_entry} ) {

        eval {

            if ( is_valid_format( { value => $handler->{data}{txt_entry}, format => 'sku' } ) ) {
            ## SKU entered
                $handler->{data}{sku} = $handler->{data}{txt_entry};
            }
            ## ID entered
            elsif ( is_valid_format( { value => $handler->{data}{txt_entry}, format => 'id' } ) ) {
                $handler->{data}{sku}        = '';
            }
            else {
                die 'Invalid value entered';
            }


            if ( $handler->{data}{sku} ) {

                $schema->txn_do(sub{
                    my $dbh = $schema->storage->dbh;
                    ## update rtv_shipment and rtv_shipment_detail statuses as necessary
                    $status_ref = get_rtv_status( { dbh => $dbh, entity => 'rtv_shipment', id => $handler->{data}{rtv_shipment_id} } );

                    if ( $status_ref->{status_id} <= $RTV_SHIPMENT_STATUS__PICKED ) {
                        update_rtv_shipment_statuses({
                            dbh                         => $dbh,
                            rtv_shipment_id             => $handler->{data}{rtv_shipment_id},
                            rtv_shipment_status         => $RTV_SHIPMENT_STATUS__PACKING,
                            rtv_shipment_detail_status  => $RTV_SHIPMENT_DETAIL_STATUS__PACKING,
                            operator_id                 => $handler->{data}{operator_id},
                        });
                    }

                    ## insert rtv_shipment_pack record
                    insert_rtv_shipment_pack({
                        dbh             => $dbh,
                        operator_id     => $handler->{data}{operator_id},
                        rtv_shipment_id => $handler->{data}{rtv_shipment_id},
                        sku             => $handler->{data}{sku},
                    });
                });
            }
        };
        if ($@) {
            $handler->{data}{error_msg} .= "\n$@";
        }
    }
    elsif ( ($handler->{data}{auth_level} == $AUTHORISATION_LEVEL__MANAGER) && ($handler->{param_of}{submit_pack_auto}) ) {

        eval {

            $schema->txn_do(sub{
                my $dbh = $schema->storage->dbh;
                ## update rtv_shipment and rtv_shipment_detail statuses as necessary
                $status_ref = get_rtv_status( { dbh => $dbh, entity => 'rtv_shipment', id => $handler->{data}{rtv_shipment_id} } );

                if ( $status_ref->{status_id} <= $RTV_SHIPMENT_STATUS__PICKED ) {
                    update_rtv_shipment_statuses({
                        dbh                         => $dbh,
                        rtv_shipment_id             => $handler->{data}{rtv_shipment_id},
                        rtv_shipment_status         => $RTV_SHIPMENT_STATUS__PACKING,
                        rtv_shipment_detail_status  => $RTV_SHIPMENT_DETAIL_STATUS__PACKING,
                        operator_id                 => $handler->{data}{operator_id},
                    });
                }

                my $auto_pack_items_ref = list_rtv_shipment_validate_pack( { dbh => $dbh, rtv_shipment_id => $handler->{data}{rtv_shipment_id} } );

                ## insert rtv_shipment_pack records
                foreach my $item_ref ( @{$auto_pack_items_ref} ) {
                    foreach ( 1..$item_ref->{remaining_to_pack} ) {
                        insert_rtv_shipment_pack({
                            dbh             => $dbh,
                            operator_id     => $handler->{data}{operator_id},
                            item_ref        => $item_ref,
                        });
                    }
                }
            });
        };
        if ($@) {
            $handler->{data}{error_msg} .= "\n$@";
        }
    }
    elsif ( $handler->{param_of}{submit_pack_rtv_commit} ) {

        eval {
            $schema->txn_do(sub{
                commit_rtv_shipment_pack({
                    dbh => $schema->storage->dbh,
                    operator_id => $handler->{data}{operator_id},
                    rtv_shipment_id => $handler->{data}{rtv_shipment_id},
                });
            });
            $handler->{data}{subsubsection}   = '';
        };
        if ($@) {
            $handler->{data}{error_msg} .= "\n$@";
        }

        eval {
            ## send email to shipping
            send_rtv_shipping_email({
                dbh => $schema->storage->dbh,
                rtv_shipment_id => $handler->{data}{rtv_shipment_id},
            });
        };
        if ($@) {
            $handler->{data}{error_msg} .= "\n$@";
        }

        $handler->{data}{rtv_shipment_id} = '';
    }
    elsif ( $handler->{param_of}{submit_pack_rtv_cancel} ) {

        eval {
            $schema->txn_do(sub{
                cancel_rtv_shipment_pack({
                    dbh => $schema->storage->dbh,
                    operator_id => $handler->{data}{operator_id},
                    rtv_shipment_id => $handler->{data}{rtv_shipment_id},
                });
            });
            $handler->{data}{rtv_shipment_id} = '';
            $handler->{data}{subsubsection}   = '';
        };
        if ($@) {
            $handler->{data}{error_msg} .= "\n$@";
        }
    }

    if ( $fetch_list and is_valid_format( { value => $handler->{data}{rtv_shipment_id}, format => 'id' } ) ) {

        $handler->{data}{subsubsection}   = "RTV Shipment $handler->{data}{rtv_shipment_id}";
        $handler->{data}{show_autopack}   = is_nonfaulty( { dbh => $handler->{dbh}, type => 'rtv_shipment_id', id => $handler->{data}{rtv_shipment_id} } );

        ## check rtv_shipment_status
        $status_ref = get_rtv_status( { dbh => $handler->{dbh}, entity => 'rtv_shipment', id => $handler->{data}{rtv_shipment_id} } );

        if (defined $status_ref->{status_id}) {
            $handler->{data}{rtv_shipment_status} = $status_ref->{status};
            ## fetch RTV shipment validation packlist
            $handler->{data}{rtv_shipment_validate_pack}  = list_rtv_shipment_validate_pack( { dbh => $handler->{dbh}, rtv_shipment_id => $handler->{data}{rtv_shipment_id} } );
        }
        else {
            xt_warn("\nRTV Shipment id $handler->{data}{rtv_shipment_id} does not exist or has an invalid status");
        }
    }

   $handler->process_template;

    return OK;
}

1;
