package XTracker::Stock::Actions::SetDeadStock;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Stock qw( insert_quantity update_quantity delete_quantity check_stock_location get_stock_location_quantity );
use XTracker::Database::Logging qw( log_rtv_stock log_location );
use XTracker::Database::Product qw(get_variant_by_sku);
use XTracker::Utilities qw(url_encode);
use XTracker::Error;

use XTracker::Constants::FromDB qw( :flow_status :rtv_action );

sub handler {
    my $handler     = XTracker::Handler->new(shift);
    my $error_msg   = '';
    my $status_msg  = '';
    my $quantity_id = $handler->{param_of}{quantity_id};

    eval {

        my $guard = $handler->schema->txn_scope_guard;
        # adjust quantity
        if ( $handler->{param_of}{action} eq 'adjust' ) {
            _adjust_stock($handler);
        }
        # add quantity
        elsif ( $handler->{param_of}{action} eq 'add' ) {
            _add_stock($handler);
        }
        # Incomplete pick
        else {
            die 'Unexpect action for SetDeadStock - '.$handler->{param_of}{action}
        }

        $guard->commit();
        xt_success('Dead stock successfully adjusted.');
    };

    if ($@) {
         $@ =~ s/at \/opt\/xt\/.*//;
        xt_warn("An error occured:<br />$@");
    }

    return $handler->redirect_to( '/StockControl/DeadStock' );
}

sub _adjust_stock {
    my ( $handler ) = @_;

    # let's do some basic input validation at least
    my $qty = $handler->{param_of}{quantity};
    die "Adjust quantity must be an integer number please" unless $qty =~ m/^-?\d+$/;
    $qty *= -1 if $qty < 0; # make positive

    # move it
    my $loc_details = {
        location    => $handler->{param_of}{location},
        status      => $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
    };
    $handler->{schema}->resultset('Public::Quantity')->move_stock({
        variant         => $handler->{param_of}{variant_id},
        channel         => $handler->{param_of}{channel_id},
        quantity        => $qty,
        from            => ($handler->{param_of}{quantity} < 0) ? $loc_details : undef,
        to              => ($handler->{param_of}{quantity} > 0) ? $loc_details : undef,
        log_location_as => $handler->{data}{operator_id},
    });

    # log it
    log_rtv_stock({
        dbh             => $handler->{dbh},
        variant_id      => $handler->{param_of}{variant_id},
        rtv_action_id   => $RTV_ACTION__MANUAL_ADJUSTMENT,
        quantity        => $handler->{param_of}{quantity},
        operator_id     => $handler->{data}{operator_id},
        notes           => $handler->{param_of}{notes},
        channel_id      => $handler->{param_of}{channel_id},
    });

    return;
}

sub _add_stock {
    my ( $handler ) = @_;

    # get variant from SKU entered
    my $variant_id = get_variant_by_sku( $handler->{dbh}, $handler->{param_of}{sku} );
    if (!$variant_id){
        die 'Could not find SKU entered ('.$handler->{param_of}{sku}.'), please check and try again.';
    }

    # validate location entered can handle dead stock
    my $location = eval {
        $handler->{schema}->resultset('Public::Location')->get_location({
                                                       location => $handler->{param_of}{location},
                                                    });
    };
    die 'Could not find location entered ('.$handler->{param_of}{location}.'), please check and try again.'
        unless $location;
    die 'The location entered ('.$handler->{param_of}{location}.') is not a Dead Stock location, please check and try again.'
        unless $location->allows_status($FLOW_STATUS__DEAD_STOCK__STOCK_STATUS);

    $handler->{schema}->resultset('Public::Quantity')->move_stock({
        variant     => $variant_id,
        channel     => $handler->{param_of}{channel_id},
        quantity    => $handler->{param_of}{quantity},
        from        => undef,
        to          => {
            location    => $location,
            status      => $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
        },
        log_location_as => $handler->{data}{operator_id}
    });

    log_rtv_stock({
        dbh             => $handler->{dbh},
        variant_id      => $variant_id,
        rtv_action_id   => $RTV_ACTION__MANUAL_ADJUSTMENT,
        quantity        => $handler->{param_of}{quantity},
        operator_id     => $handler->{data}{operator_id},
        notes           => $handler->{param_of}{notes},
        channel_id      => $handler->{param_of}{channel_id},
    });

    return;

}

1;
