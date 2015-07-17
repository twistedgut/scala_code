package XTracker::Stock::ChannelTransfer::Putaway;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Navigation;
use XTracker::Database::ChannelTransfer qw( get_channel_transfer get_channel_transfer_pick get_channel_transfer_putaway );
use XTracker::Database::Product qw( get_product_summary get_variant_list get_variant_by_sku get_variant_product_data );
use XTracker::Constants::FromDB qw( :channel_transfer_status );
use XTracker::Logfile qw( xt_logger );
use XTracker::Error;

my $logger = xt_logger();

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Channel Transfer';
    $handler->{data}{subsubsection} = 'Putaway Transfer';
    $handler->{data}{content}       = 'stocktracker/channel_transfer/putaway.tt';
    $handler->{data}{view}          = $handler->{param_of}{view};

    if ( !$handler->{param_of}{transfer_id} ) {
        return $handler->redirect_to( '/StockControl/ChannelTransfer?list_type=Putaway' );
    }

    # get transfer details
    $handler->{data}{transfer_id}   = $handler->{param_of}{transfer_id};
    $handler->{data}{transfer}      = get_channel_transfer( $handler->{dbh}, { transfer_id => $handler->{data}{transfer_id} } );

    # kick user back if no transfer found
    if ( !$handler->{data}{transfer} ) {
        xt_warn("Could not find transfer record for value entered: '.$handler->{data}{transfer_id}");
        return $handler->redirect_to( '/StockControl/ChannelTransfer?list_type=Putaway&view='.$handler->{data}{view});
    }

    # kick user back if transfer not corredct status to be picked
    if ( $handler->{data}{transfer}{status_id} != $CHANNEL_TRANSFER_STATUS__PICKED && !$handler->{param_of}{error_msg} && !$handler->{param_of}{display_msg} ) {
        xt_warn("The transfer is not the correct status to be putaway, current status: '.$handler->{data}{transfer}{status}");
        return $handler->redirect_to( '/StockControl/ChannelTransfer?list_type=Putaway&view='.$handler->{data}{view} );
    }

    $handler->{data}{sales_channel} = $handler->{data}{transfer}{from_channel};
    $handler->{data}{product_id}    = $handler->{data}{transfer}{product_id};
    $handler->{data}{pick}          = get_channel_transfer_pick( $handler->{dbh}, { transfer_id => $handler->{data}{transfer_id} } );
    $handler->{data}{putaway}       = get_channel_transfer_putaway( $handler->{dbh}, { transfer_id => $handler->{data}{transfer_id} } );
    $handler->{data}{variants}      = get_variant_list( $handler->{dbh}, { type => 'product_id', id => $handler->{data}{transfer}{product_id}, exclude_iws => 1, exclude_prl => 1 }, { by => 'size_list' } );

    # info for product header & side nav
    if ( $handler->{data}{view} ne 'HandHeld' ) {
        $handler->{data}{sidenav} = build_sidenav( { navtype => 'channel_transfer' } );
        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );
    }

    # convert pick data into a useful format
    foreach my $pickid ( keys %{$handler->{data}{pick}} ) {
        $handler->{data}{pick_data}{ $handler->{data}{pick}{$pickid}{variant_id} }{ $handler->{data}{pick}{$pickid}{location_id} } = $handler->{data}{pick}{$pickid};
    }

    # convert putaway data into a useful format
    foreach my $putawayid ( keys %{$handler->{data}{putaway}} ) {
        $handler->{data}{putaway_data}{ $handler->{data}{putaway}{$putawayid}{variant_id} }{ $handler->{data}{putaway}{$putawayid}{location_id} } = $handler->{data}{putaway}{$putawayid};
    }


    # work out next putaway item
    ($handler->{data}{next_variant}, $handler->{data}{next_quantity}) = _next_putaway($handler);

    return $handler->process_template;
}


sub _next_putaway {

    my $handler = shift;

    # loop over pick records and workout next putaway item
    foreach my $variant_id ( sort {$a <=> $b} keys %{$handler->{data}{pick_data}} ) {

        # calculate total pick qty for variant
        my $picked_quantity = 0;
        foreach my $location_id ( keys %{ $handler->{data}{pick_data}{$variant_id} } ) {
            $picked_quantity += $handler->{data}{pick_data}{$variant_id}{$location_id}{picked_quantity};
        }

        # check if putaway quantity less than picked quantity
        my $putaway_quantity = 0;
        if ( $handler->{data}{putaway_data}{$variant_id} ) {
            foreach my $location_id ( keys %{ $handler->{data}{putaway_data}{$variant_id} } ) {
                $putaway_quantity += $handler->{data}{putaway_data}{$variant_id}{$location_id}{quantity};
            }
        }

        if ( $picked_quantity > $putaway_quantity) {
            return $variant_id, ($picked_quantity - $putaway_quantity);
        }
    }

    return;
}

1;
