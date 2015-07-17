package XTracker::Stock::RTV::InspectPick;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Constants::FromDB qw(:rtv_inspection_pick_request_status :authorisation_level);
use XTracker::Database          qw(:common);
use XTracker::Database::RTV     qw(:rtv_stock :rtv_inspection_pick :validate get_rtv_status update_rtv_status);
use XTracker::Navigation;
use XTracker::Utilities         qw(:edit :string);
use XTracker::XTemplate;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{section}               = 'RTV';
    $handler->{data}{subsection}            = 'Inspection Pick';
    $handler->{data}{subsubsection}         = '';
    $handler->{data}{content}               = 'rtv/inspect_rtv_pick.tt';
    $handler->{data}{tt_process_block}      = undef;
    $handler->{data}{operator_auth_level}   = $handler->{data}{auth_level};
    $handler->{data}{AUTH_LEVEL_MANAGER}    = $AUTHORISATION_LEVEL__MANAGER;


    $handler->{data}{view}                            = defined $handler->{param_of}{view} ? lc($handler->{param_of}{view}) : '';
    $handler->{data}{rtv_inspection_pick_request_id}  = defined $handler->{param_of}{rtv_inspection_pick_request_id} ? $handler->{param_of}{rtv_inspection_pick_request_id}  : '';


    ## remove 'RTVI-' prefix if necessary (i.e. for scanned input)
    $handler->{data}{rtv_inspection_pick_request_id} = $handler->{data}{rtv_inspection_pick_request_id} =~ m{\ARTVI-(\d+)\z}xms ? $1 : $handler->{data}{rtv_inspection_pick_request_id};

    $handler->{data}{txt_entry} = defined $handler->{param_of}{txt_entry}    ? $handler->{param_of}{txt_entry}    : '';
    $handler->{data}{txt_entry} = trim( $handler->{data}{txt_entry} );

    $handler->{data}{location}  = defined $handler->{param_of}{hdn_location} ? $handler->{param_of}{hdn_location} : '';

    my $fetch_list  = $handler->{data}{rtv_inspection_pick_request_id}   =~ m{\A\d+\z}xms    ? 1
                    : $handler->{param_of}{submit_pick_rtv_entry}             ? 1 ## submit - scanned entry
                    : $handler->{param_of}{submit_pick_rtv_commit}            ? 0 ## submit - commit pick
                    : $handler->{param_of}{submit_pick_rtv_cancel}            ? 0 ## submit - cancel pick
                    :                                                         0
                    ;



    if ( $handler->{data}{view} eq 'handheld' ) {
        $handler->{data}{tt_process_block}    = 'inspect_rtv_pick_handheld';
    }
    else {
        $handler->{data}{tt_process_block}    = 'inspect_rtv_pick';
    }


    my $schema = $handler->schema;
    if ( $handler->{param_of}{submit_pick_rtv_entry} ) {
        eval {

            if ( is_valid_format( { value => $handler->{data}{txt_entry}, format => 'location' } ) ) {
            ## location entered
                $handler->{data}{location}   = uc($handler->{data}{txt_entry});
                $handler->{data}{sku}        = '';
            }
            elsif ( is_valid_format( { value => $handler->{data}{txt_entry}, format => 'sku' } ) ) {
            ## SKU entered
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
                    ## update rtv_inspection_pick_request status as necessary
                    my $status_ref = get_rtv_status({
                        dbh => $dbh,
                        entity => 'rtv_inspection_pick_request',
                        id => $handler->{data}{rtv_inspection_pick_request_id},
                    });

                    if ( $status_ref->{status_id} <= $RTV_INSPECTION_PICK_REQUEST_STATUS__NEW ) {
                        update_rtv_status({
                            dbh         => $dbh,
                            entity      => 'rtv_inspection_pick_request',
                            type        => 'rtv_inspection_pick_request_id',
                            id          => $handler->{data}{rtv_inspection_pick_request_id},
                            status_id   => $RTV_INSPECTION_PICK_REQUEST_STATUS__PICKING,
                            operator_id => $handler->{data}{operator_id},
                        });
                    }

                    ## insert rtv_inspection_pick record
                    insert_rtv_inspection_pick({
                        dbh                             => $dbh,
                        operator_id                     => $handler->{data}{operator_id},
                        rtv_inspection_pick_request_id  => $handler->{data}{rtv_inspection_pick_request_id},
                        location                        => $handler->{data}{location},
                        sku                             => $handler->{data}{sku},
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
                ## update rtv_inspection_pick_request status as necessary
                my $status_ref = get_rtv_status({
                    dbh => $dbh,
                    entity => 'rtv_inspection_pick_request',
                    id => $handler->{data}{rtv_inspection_pick_request_id},
                });

                if ( $status_ref->{status_id} <= $RTV_INSPECTION_PICK_REQUEST_STATUS__NEW ) {
                    update_rtv_status({
                        dbh         => $dbh,
                        entity      => 'rtv_inspection_pick_request',
                        type        => 'rtv_inspection_pick_request_id',
                        id          => $handler->{data}{rtv_inspection_pick_request_id},
                        status_id   => $RTV_INSPECTION_PICK_REQUEST_STATUS__PICKING,
                        operator_id => $handler->{data}{operator_id},
                    });
                }

                my $auto_pick_items_ref = list_rtv_inspection_validate_pick( { dbh => $dbh, rtv_inspection_pick_request_id => $handler->{data}{rtv_inspection_pick_request_id} } );

                ## insert rtv_shipment_pick records
                foreach my $item_ref ( @{$auto_pick_items_ref} ) {
                    foreach ( 1..$item_ref->{remaining_to_pick} ) {

                        ## insert rtv_inspection_pick record
                        insert_rtv_inspection_pick({
                            dbh                             => $dbh,
                            operator_id                     => $handler->{data}{operator_id},
                            rtv_inspection_pick_request_id  => $handler->{data}{rtv_inspection_pick_request_id},
                            location                        => $item_ref->{location},
                            sku                             => $item_ref->{sku},
                        });
                    }
                }
            });
        };
        if ($@) {
            $handler->{data}{error_msg} .= "\n$@";
        }
    }
    elsif ( $handler->{param_of}{submit_pick_rtv_commit} ) {
        eval {
            $schema->txn_do(sub{
                my $dbh = $schema->storage->dbh;
                commit_rtv_inspection_pick({
                    dbh                             => $dbh,
                    operator_id                     => $handler->{data}{operator_id},
                    rtv_inspection_pick_request_id  => $handler->{data}{rtv_inspection_pick_request_id},
                });
                $handler->{data}{rtv_inspection_pick_request_id}  = '';
                $handler->{data}{subsubsection}                   = '';
            });
        };
        if ($@) {
            $handler->{data}{error_msg} .= "\n$@";
        }
    }
    elsif ( $handler->{param_of}{submit_pick_rtv_cancel} ) {
        eval {
            $schema->txn_do(sub{
                cancel_rtv_inspection_pick({
                    dbh                             => $schema->storage->dbh,
                    operator_id                     => $handler->{data}{operator_id},
                    rtv_inspection_pick_request_id  => $handler->{data}{rtv_inspection_pick_request_id},
                });
                $handler->{data}{rtv_inspection_pick_request_id}  = '';
                $handler->{data}{subsubsection}                   = '';
            });
        };
        if ($@) {
            $handler->{data}{error_msg} .= "\n$@";
        }
    }

    if ( $fetch_list and is_valid_format( { value => $handler->{data}{rtv_inspection_pick_request_id}, format => 'id' } ) ) {

        $handler->{data}{subsubsection}   = "Inspection Pick Request $handler->{data}{rtv_inspection_pick_request_id}";

        ## check rtv_inspection_pick_request_status
        my $status_ref = get_rtv_status( { dbh => $handler->{dbh}, entity => 'rtv_inspection_pick_request', id => $handler->{data}{rtv_inspection_pick_request_id} } );
        die "RTV Inspection Pick Request id $handler->{data}{rtv_inspection_pick_request_id} does not exist or has an invalid status\n" unless defined $status_ref->{status_id};
        $handler->{data}{rtv_inspection_pick_request_status} = $status_ref->{status};


        ## fetch RTV inspection validation picklist
        $handler->{data}{rtv_inspection_validate_pick} = list_rtv_inspection_validate_pick({
                    dbh                             => $handler->{dbh},
                    rtv_inspection_pick_request_id  => $handler->{data}{rtv_inspection_pick_request_id}
        });

    }

    $handler->process_template;

    return OK;
}

1;
