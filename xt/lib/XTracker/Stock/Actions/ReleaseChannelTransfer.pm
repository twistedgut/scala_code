package XTracker::Stock::Actions::ReleaseChannelTransfer;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::ChannelTransfer qw( get_channel_transfer set_channel_transfer_status );
use XTracker::Utilities qw( url_encode );
use XTracker::Constants::FromDB qw( :channel_transfer_status );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);
    my $error_msg   = '';
    my $status_msg  = '';

    # get transfer details
    my $transfer_id = $handler->{param_of}{transfer_id};
    my $transfer    = get_channel_transfer( $handler->{dbh}, { transfer_id => $transfer_id } );

    # kick user back if no transfer found
    if ( !$transfer ) {
        xt_warn("Could not find transfer record for value entered: $transfer_id");
        return $handler->redirect_to( '/StockControl/ChannelTransfer/View?transfer_id='.$transfer_id );
    }

    # kick user back if transfer not correct status to be released
    if ( $transfer->{status_id} != $CHANNEL_TRANSFER_STATUS__INCOMPLETE_PICK ) {
        xt_warn("The transfer is not the correct status to be released, current status: $transfer->{status}" );
        return $handler->redirect_to( '/StockControl/ChannelTransfer/View?transfer_id='.$transfer_id );
    }

    # set transfer status to 'selected'
    set_channel_transfer_status( $handler->{dbh}, { transfer_id => $transfer_id, operator_id => $handler->{data}{operator_id}, status_id => $CHANNEL_TRANSFER_STATUS__SELECTED } );

    xt_success('Transfer released for picking.');
    return $handler->redirect_to( '/StockControl/ChannelTransfer/View?transfer_id='.$transfer_id );

}

1;

