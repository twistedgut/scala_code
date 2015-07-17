package XTracker::Stock::ChannelTransfer::Pick;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Navigation;
use XTracker::Database::ChannelTransfer qw( get_channel_transfer get_channel_transfer_pick );
use XTracker::Database::Product qw( get_product_summary get_variant_list get_variant_by_sku get_variant_product_data );
use XTracker::Database::Stock qw( get_allocated_item_quantity get_located_stock );
use XTracker::Constants::FromDB qw( :channel_transfer_status :flow_status );
use XTracker::Logfile qw( xt_logger );
use XTracker::Error;

my $logger = xt_logger();

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $dbh = $handler->dbh;
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Channel Transfer';
    $handler->{data}{subsubsection} = 'Pick Transfer';
    $handler->{data}{content}       = 'stocktracker/channel_transfer/pick.tt';
    $handler->{data}{view}          = $handler->{param_of}{view};

    my $redirect_url = '/StockControl/ChannelTransfer?list_type=Picking'
                     . ( $handler->{data}{view} ? "&view=$handler->{data}{view}" : q{} );
    if ( !$handler->{param_of}{transfer_id} ) {
        return $handler->redirect_to( $redirect_url );
    }

    # get transfer details
    $handler->{data}{transfer_id} = $handler->{param_of}{transfer_id};
    $handler->{data}{transfer}    = get_channel_transfer( $dbh, { transfer_id => $handler->{data}{transfer_id} } );

    # kick user back if no transfer found
    if ( !$handler->{data}{transfer} ) {
        xt_warn("Could not find transfer record for value entered: '.$handler->{data}{transfer_id}");
        return $handler->redirect_to( $redirect_url );
    }

    # kick user back if transfer not corredct status to be picked
    if ( $handler->{data}{transfer}{status_id} != $CHANNEL_TRANSFER_STATUS__SELECTED && !$handler->{param_of}{error_msg} && !$handler->{param_of}{display_msg} ) {
        xt_warn("The transfer is not the correct status to be picked, current status: '.$handler->{data}{transfer}{status}");
        return $handler->redirect_to( $redirect_url );
    }

    $handler->{data}{sales_channel} = $handler->{data}{transfer}{from_channel};
    $handler->{data}{product_id}    = $handler->{data}{transfer}{product_id};
    $handler->{data}{pick}          = get_channel_transfer_pick( $dbh, { transfer_id => $handler->{data}{transfer_id} } );
    $handler->{data}{stock}         = get_located_stock( $dbh,
                                                         { type        => 'product_id',
                                                           id          => $handler->{data}{transfer}{product_id},
                                                           exclude_prl => 1,
                                                           exclude_iws => 1
                                                         },
                                                         'stock_main'
                                                       );
    $handler->{data}{main_status_id} = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;
    $handler->{data}{variants}      = get_variant_list( $dbh,
                                                        { type        => 'product_id',
                                                          id          => $handler->{data}{transfer}{product_id},
                                                          exclude_prl => 1,
                                                          exclude_iws => 1
                                                        },
                                                        { by => 'size_list' }
                                                      );

    # info for product header & side nav
    if ( $handler->{data}{view} ne 'HandHeld' ) {
        $handler->{data}{sidenav} = build_sidenav( { navtype => 'channel_transfer' } );
        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );
    }


    # location entered by user
    if ( $handler->{param_of}{location} && !$handler->{param_of}{location_id} ) {
        $handler->{data}{location} = $handler->{param_of}{location};
        $logger->debug("Checking location: $handler->{data}{location}");
        _process_location($handler);
    }

    # sku entered by user
    if ( $handler->{param_of}{sku} && !$handler->{param_of}{variant_id} ) {
        $handler->{data}{location}      = $handler->{param_of}{location};
        $handler->{data}{location_id}   = $handler->{param_of}{location_id};
        $handler->{data}{sku}           = $handler->{param_of}{sku};
        $logger->debug("Location stored: $handler->{data}{location}");
        $logger->debug("Checking SKU: $handler->{data}{sku}");
        _process_sku($handler);
    }

    return $handler->process_template;
}


sub _process_location {
    my $handler = shift;

    # get location info for location
    my $location = eval {
        $handler->schema->resultset('Public::Location')->get_location({
                                                       location => $handler->{data}{location},
                                                    });
    };
    unless($location){
        $handler->{data}{error_msg} = "The location entered could not be found.  Please try again.";
        return;
    }
    $handler->{data}{location_id} = $location->id;


    # not a main stock location entered, switch process back and give message for user
    if ( !$location->allows_status($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS) ) {
        $handler->{data}{error_msg} = "The location entered was not a valid main stock location.";
        delete $handler->{data}{location_id};
        return;
    }

    $logger->debug("Found location_id: $handler->{data}{location_id}");

    return;
}


sub _process_sku {

    my $handler = shift;

    # get id for variant
    $handler->{data}{variant_id} = get_variant_by_sku( $handler->dbh, $handler->{data}{sku} );

    # invalid location entered switch process back and give message to user
    if ( !$handler->{data}{variant_id} ) {
        $handler->{data}{error_msg} = "The SKU entered could not be found.  Please try again.";
        return;
    }

    $handler->{data}{prod_info} = get_variant_product_data( $handler->dbh, $handler->{data}{variant_id} );

    # PID of variant doesn't match PID of transfer
    if ( $handler->{data}{prod_info}{product_id} != $handler->{data}{transfer}{product_id} ) {
        $handler->{data}{error_msg} = "The SKU entered ($handler->{param_of}{sku}) does not match the product being transferred ($handler->{data}{transfer}{product_id}).";
        $handler->{data}{variant_id} = 0;
        return;
    }

    # no record of the SKU in the location entered
    if ( !$handler->{data}{stock}{ $handler->{data}{transfer}{from_channel} }{ $handler->{data}{variant_id} }{ $handler->{data}{location_id} } ) {
        $handler->{data}{error_msg} = "There is no record of the SKU entered ($handler->{param_of}{sku}) in the location entered ($handler->{param_of}{location}), please check and try again.";
        $handler->{data}{variant_id} = 0;
        $handler->{data}{location_id} = 0;
        return;
    }

    $logger->debug("Found variant_id: $handler->{data}{variant_id}");

    return;
}

1;
