package XTracker::Stock::ChannelTransfer::View;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Navigation;
use XTracker::Database::ChannelTransfer qw( get_channel_transfer get_channel_transfer_log get_channel_transfer_pick get_channel_transfer_putaway );
use XTracker::Database::Product qw( get_product_summary );
use XTracker::Constants::FromDB qw( :channel_transfer_status );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Channel Transfer';
    $handler->{data}{subsubsection} = 'View Transfer';
    $handler->{data}{content}       = 'stocktracker/channel_transfer/view.tt';
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'channel_transfer' } );

    if ( !$handler->{param_of}{transfer_id} ) {
        return $handler->redirect_to( '/StockControl/ChannelTransfer' );
    }

    # get transfer details
    $handler->{data}{transfer_id}   = $handler->{param_of}{transfer_id};
    $handler->{data}{transfer}      = get_channel_transfer( $handler->{dbh}, { transfer_id => $handler->{data}{transfer_id} } );
    $handler->{data}{sales_channel} = $handler->{data}{transfer}{from_channel};
    $handler->{data}{product_id}    = $handler->{data}{transfer}{product_id};
    $handler->{data}{log}           = get_channel_transfer_log( $handler->{dbh}, { transfer_id => $handler->{data}{transfer_id} } );
    $handler->{data}{pick}          = get_channel_transfer_pick( $handler->{dbh}, { transfer_id => $handler->{data}{transfer_id} } );
    $handler->{data}{putaway}       = get_channel_transfer_putaway( $handler->{dbh}, { transfer_id => $handler->{data}{transfer_id} } );

    # info for product header
    $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

    return $handler->process_template;
}

1;
