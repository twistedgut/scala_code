package XTracker::Stock::RTV::PickRTV;

use strict;
use warnings;
use Carp;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Constants::FromDB qw(:rtv_shipment_status :rtv_shipment_detail_status :authorisation_level);
use XTracker::Database::RTV     qw(:rtv_stock :rtv_shipment :rtv_shipment_pick :validate :logging get_rtv_status update_rtv_status is_nonfaulty);
use XTracker::Utilities         qw(:edit :string);

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}               = 'RTV';
    $handler->{data}{subsection}            = 'Shipment Pick';
    $handler->{data}{subsubsection}         = '';
    $handler->{data}{content}               = 'rtv/pick_rtv.tt';
    $handler->{data}{tt_process_block}      = '';
    $handler->{data}{operator_auth_level}   = $handler->{data}{auth_level};
    $handler->{data}{AUTH_LEVEL_MANAGER}    = $AUTHORISATION_LEVEL__MANAGER;


    $handler->{data}{view}            = defined $handler->{param_of}{view} ? lc($handler->{param_of}{view}) : '';
    $handler->{data}{rtv_shipment_id} = defined $handler->{param_of}{rtv_shipment_id} ? $handler->{param_of}{rtv_shipment_id}  : '';

    # remove 'RTVS-' prefix if necessary (i.e. for scanned input)
    $handler->{data}{rtv_shipment_id}    = $handler->{data}{rtv_shipment_id} =~ m{\ARTVS-(\d+)\z}xms ? $1 : $handler->{data}{rtv_shipment_id};

    $handler->{data}{txt_entry} = defined $handler->{param_of}{txt_entry}    ? $handler->{param_of}{txt_entry}    : '';
    $handler->{data}{txt_entry} = trim($handler->{data}{txt_entry});

    $handler->{data}{location}   = defined $handler->{param_of}{hdn_location} ? $handler->{param_of}{hdn_location} : '';

    my $fetch_list  = $handler->{data}{rtv_shipment_id}  =~ m{\A\d+\z}xms            ? 1
                    : $handler->{param_of}{submit_pick_rtv_entry}     ? 1 ## submit - scanned entry
                    : $handler->{param_of}{submit_pick_auto}          ? 1 ## submit - auto-pick selected
                    : $handler->{param_of}{submit_pick_rtv_commit}    ? 0 ## submit - commit pick
                    : $handler->{param_of}{submit_pick_rtv_cancel}    ? 0 ## submit - cancel pick
                    :                                                 0
                    ;


    my $status_ref;

    if ( $handler->{data}{view} eq 'HandHeld' ) {
        $handler->{data}{tt_process_block}    = 'pick_rtv_handheld';
    }
    else {
        $handler->{data}{tt_process_block}    = 'pick_rtv';
    }


    # form submitted
    my $schema = $handler->schema;
    if ( $handler->{param_of}{'submit_pick_rtv_entry'} ) {

        eval {

            ## location entered
            if ( is_valid_format( { value => $handler->{data}{txt_entry}, format => 'location' } ) ) {
                $handler->{data}{location}   = uc($handler->{data}{txt_entry});
                $handler->{data}{sku}        = '';
            }
            ## SKU entered
            elsif ( is_valid_format( { value => $handler->{data}{txt_entry}, format => 'sku' } ) ) {
                die "Please select a location before entering a SKU\n" unless $handler->{data}{location};
                $handler->{data}{sku} = $handler->{data}{txt_entry};
            }
            ## ID entered
            elsif ( is_valid_format( { value => $handler->{data}{txt_entry}, format => 'id' } ) ) {
                $handler->{data}{location}   = '';
                $handler->{data}{sku}        = '';
            }
            else {
                die "Invalid value entered - $handler->{data}{txt_entry}\n";
            }

            if ( $handler->{data}{location} && $handler->{data}{sku} ) {
                $schema->txn_do(sub{
                    my $dbh = $schema->storage->dbh;
                    # update rtv_shipment and rtv_shipment_detail statuses as necessary
                    $status_ref = get_rtv_status({
                        dbh => $dbh,
                        entity => 'rtv_shipment',
                        id => $handler->{data}{rtv_shipment_id},
                    });

                    if ( $status_ref->{status_id} <= $RTV_SHIPMENT_STATUS__NEW ) {
                        update_rtv_shipment_statuses({
                            dbh                         => $dbh,
                            rtv_shipment_id             => $handler->{data}{rtv_shipment_id},
                            rtv_shipment_status         => $RTV_SHIPMENT_STATUS__PICKING,
                            rtv_shipment_detail_status  => $RTV_SHIPMENT_DETAIL_STATUS__PICKING,
                            operator_id                 => $handler->{data}{operator_id},
                        });
                    }

                    ## insert rtv_shipment_pick record
                    insert_rtv_shipment_pick({
                        dbh             => $dbh,
                        operator_id     => $handler->{data}{operator_id},
                        rtv_shipment_id => $handler->{data}{rtv_shipment_id},
                        location        => $handler->{data}{location},
                        sku             => $handler->{data}{sku},
                    });
                });
            }
        };
        if ($@) {
            $handler->{data}{error_msg} .= "\n$@";
        }

    }
    elsif ( ($handler->{data}{auth_level} == $AUTHORISATION_LEVEL__MANAGER) && $handler->{param_of}{'submit_pick_auto'} ) {

        eval {

            $schema->txn_do(sub{
                my $dbh = $schema->storage->dbh;
                ## update rtv_shipment and rtv_shipment_detail statuses as necessary
                $status_ref = get_rtv_status( { dbh => $dbh, entity => 'rtv_shipment', id => $handler->{data}{rtv_shipment_id} } );

                if ( $status_ref->{status_id} <= $RTV_SHIPMENT_STATUS__NEW ) {
                    update_rtv_shipment_statuses({
                        dbh                         => $dbh,
                        rtv_shipment_id             => $handler->{data}{rtv_shipment_id},
                        rtv_shipment_status         => $RTV_SHIPMENT_STATUS__PICKING,
                        rtv_shipment_detail_status  => $RTV_SHIPMENT_DETAIL_STATUS__PICKING,
                        operator_id                 => $handler->{data}{operator_id},
                    });
                }

                my $auto_pick_items_ref = list_rtv_shipment_validate_pick( { dbh => $dbh, rtv_shipment_id => $handler->{data}{rtv_shipment_id} } );

                ## insert rtv_shipment_pick records
                foreach my $item_ref ( @{$auto_pick_items_ref} ) {
                    foreach ( 1..$item_ref->{remaining_to_pick} ) {
                        insert_rtv_shipment_pick({
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
    elsif ( $handler->{param_of}{'submit_pick_rtv_commit'} ) {

        eval {
            $schema->txn_do(sub{
                commit_rtv_shipment_pick( { dbh => $schema->storage->dbh, operator_id => $handler->{data}{operator_id}, rtv_shipment_id => $handler->{data}{rtv_shipment_id} } );
            });
            $handler->{data}{rtv_shipment_id} = '';
            $handler->{data}{subsubsection}   = '';
        };
        if ($@) {
            $handler->{data}{error_msg} .= "\n$@";
        }

    }
    elsif ( $handler->{param_of}{'submit_pick_rtv_cancel'} ) {

        eval {
            $schema->txn_do(sub{
                cancel_rtv_shipment_pick( { dbh => $schema->storage->dbh, operator_id => $handler->{data}{operator_id}, rtv_shipment_id => $handler->{data}{rtv_shipment_id} } );
            });
            $handler->{data}{rtv_shipment_id} = '';
            $handler->{data}{subsubsection}   = '';
        };
        if ($@) {
            $handler->{data}{error_msg} .= "\n$@";
        }

    }


    if ( $fetch_list && is_valid_format( { value => $handler->{data}{rtv_shipment_id}, format => 'id' } ) ) {

        my $is_nonfaulty                = is_nonfaulty( { dbh => $handler->{dbh}, type => 'rtv_shipment_id', id => $handler->{data}{rtv_shipment_id} } );
        $handler->{data}{is_nonfaulty}  = $is_nonfaulty;
        $handler->{data}{subsubsection} = "RTV Shipment $handler->{data}{rtv_shipment_id}";
        $handler->{data}{subsubsection} .= ' (Non-Faulty)' if $is_nonfaulty;

        # check rtv_shipment_status
        my $status_ref = get_rtv_status( { dbh => $handler->{dbh}, entity => 'rtv_shipment', id => $handler->{data}{rtv_shipment_id} } );
        die "RTV Shipment id $handler->{data}{rtv_shipment_id} does not exist or has an invalid status\n" unless defined $status_ref->{status_id};
        $handler->{data}{rtv_shipment_status} = $status_ref->{status};

        # fetch RTV shipment validation picklist
        $handler->{data}{rtv_shipment_validate_pick}  = list_rtv_shipment_validate_pick( { dbh => $handler->{dbh}, rtv_shipment_id => $handler->{data}{rtv_shipment_id} } );

        $handler->{data}{sales_channel} = $handler->{data}{rtv_shipment_validate_pick}->[0]{sales_channel};
    }

    $handler->process_template;

    return OK;
}

1;
