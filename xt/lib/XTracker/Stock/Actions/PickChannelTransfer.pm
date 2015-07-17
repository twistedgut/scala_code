package XTracker::Stock::Actions::PickChannelTransfer;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database                  qw( get_database_handle );
use XTracker::Database::ChannelTransfer qw( create_channel_transfer_pick get_channel_transfer get_channel_transfer_pick set_channel_transfer_status cancel_channel_transfer_pick );
use XTracker::Database::Product         qw( product_present );
use XTracker::Database::Stock           qw( update_quantity delete_quantity check_stock_location get_stock_location_quantity );
use XTracker::Database::Logging         qw( log_stock log_location );
use XTracker::Utilities                 qw( url_encode );
use XTracker::Comms::FCP                qw( update_web_stock_level );
use XTracker::Database::Channel         qw( get_channels get_channel_details );
use XTracker::Constants::FromDB         qw( :channel_transfer_status :pws_action :stock_action :flow_status );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);
    my $error_msg   = '';
    my $status_msg  = '';
    my $view        = $handler->{param_of}{view};
    my $transfer_id = $handler->{param_of}{transfer_id};

    eval {
        my $guard = $handler->schema->txn_scope_guard;

        # pick recorded
        if ( $handler->{param_of}{action} eq 'Pick' ) {
            _record_pick($handler);
        }

        # Cancel pick
        if ( $handler->{param_of}{action} eq 'Cancel' ) {
            _cancel_pick($handler);
        }

        # Incomplete pick
        if ( $handler->{param_of}{action} eq 'Incomplete' ) {
            _set_incomplete_pick($handler);
        }

        # Complete pick
        if ( $handler->{param_of}{action} eq 'Complete' ) {
            _complete_pick($handler);
        }

        $guard->commit();
    };

    if ($@) {
         $@ =~ s/at \/opt\/xt\/.*//;
        xt_warn("An error occured:<br />$@");
        $handler->{data}{redirect} = '/StockControl/ChannelTransfer/Pick?transfer_id='.$handler->{param_of}{transfer_id};
    }

    xt_success($handler->{data}{display_msg}) if $handler->{data}{display_msg};
    my $redirect_url = $handler->{data}{redirect} . '&view='.$view;

    return $handler->redirect_to( $redirect_url );

}


sub _record_pick {

    my ( $handler ) = @_;

    # check if picked already
    my $picked = get_channel_transfer_pick( $handler->dbh, { transfer_id => $handler->{param_of}{transfer_id} } );

    foreach my $id ( keys %{$picked} ) {
        if ( $picked->{$id}{variant_id} == $handler->{param_of}{variant_id} && $picked->{$id}{location_id} == $handler->{param_of}{location_id} ) {
            die 'SKU '.$handler->{param_of}{sku}.' has already been picked from location '.$handler->{param_of}{location}.', if an error was made please use \'Cancel Pick\' and start again.';
        }
    }

    create_channel_transfer_pick(
        $handler->dbh,
        {
            transfer_id         => $handler->{param_of}{transfer_id},
            variant_id          => $handler->{param_of}{variant_id},
            location_id         => $handler->{param_of}{location_id},
            expected_quantity   => $handler->{param_of}{expected_quantity},
            picked_quantity     => $handler->{param_of}{quantity},
            operator_id         => $handler->{data}{operator_id},
        }
    );

    $handler->{data}{redirect}      = '/StockControl/ChannelTransfer/Pick?transfer_id='.$handler->{param_of}{transfer_id};
    $handler->{data}{display_msg}   = 'Pick recorded';

    return;

}

sub _cancel_pick {

    my ( $handler ) = @_;

    cancel_channel_transfer_pick(
        $handler->dbh,
        {
            transfer_id         => $handler->{param_of}{transfer_id},
            operator_id         => $handler->{data}{operator_id},
        }
    );

    $handler->{data}{redirect}      = '/StockControl/ChannelTransfer/Pick?transfer_id='.$handler->{param_of}{transfer_id};
    $handler->{data}{display_msg}   = 'Pick cancelled';

    return;

}

sub _set_incomplete_pick {

    my ( $handler ) = @_;

    # set status of transfer
    set_channel_transfer_status( $handler->dbh, { transfer_id => $handler->{param_of}{transfer_id}, operator_id => $handler->{data}{operator_id}, status_id => $CHANNEL_TRANSFER_STATUS__INCOMPLETE_PICK } );

    $handler->{data}{redirect}      = '/StockControl/ChannelTransfer?list_type=Picking';
    $handler->{data}{display_msg}   = 'Pick set as incomplete for transfer: '.$handler->{param_of}{transfer_id};

    return;

}

sub _complete_pick {

    my ( $handler ) = @_;

    # get all pick records and decrement stock
    my $transfer    = get_channel_transfer( $handler->dbh, { transfer_id => $handler->{param_of}{transfer_id} } );
    my $picked      = get_channel_transfer_pick( $handler->dbh, { transfer_id => $handler->{param_of}{transfer_id} } );

    foreach my $id ( keys %{$picked} ) {

        # update quantity record
        update_quantity(
            $handler->dbh,
            {
                variant_id  => $picked->{$id}{variant_id},
                location    => $picked->{$id}{location},
                quantity    => ($picked->{$id}{expected_quantity} * -1),
                type        => 'dec',
                channel_id  => $transfer->{from_channel_id},
                current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
             }
        );

        # log update
        log_stock(
            $handler->dbh,
            {
                variant_id  => $picked->{$id}{variant_id},
                action      => $STOCK_ACTION__CHANNEL_TRANSFER_OUT,
                quantity    => ($picked->{$id}{expected_quantity} * -1),
                operator_id => $handler->{data}{operator_id},
                notes       => 'Channel Transfer Pick',
                channel_id  => $transfer->{from_channel_id},
            },
        );


        # delete quantity record if location now empty
        my $old_quantity = get_stock_location_quantity(
            $handler->dbh,
            {
                variant_id  => $picked->{$id}{variant_id},
                location    => $picked->{$id}{location},
                channel_id  => $transfer->{from_channel_id},
                status_id   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            }
        );

        if ( $old_quantity == 0 ) {
            delete_quantity(
                $handler->dbh,
                {
                    variant_id  => $picked->{$id}{variant_id},
                    location    => $picked->{$id}{location},
                    channel_id  => $transfer->{from_channel_id},
                    status_id   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                }
            );

            log_location(
                $handler->dbh,
                {
                    variant_id  => $picked->{$id}{variant_id},
                    location_id => $picked->{$id}{location_id},
                    channel_id  => $transfer->{from_channel_id},
                    operator_id => $handler->{data}{operator_id},
                 }
            );
        }


        # adjust website if product is live
        if ( product_present( $handler->dbh, { type => 'variant_id', id => $picked->{$id}{variant_id}, channel_id => $transfer->{from_channel_id} } ) ) {

            # get sales channel info
            my $config_section  = '';
            my $channels        = get_channels( $handler->dbh );
            foreach my $channel_id ( keys %$channels) {
                if ( $channel_id == $transfer->{from_channel_id}) {
                    $config_section = $channels->{$channel_id}{config_section};
                }
            }

            if (!$config_section) {
                die 'Unable to get channel config section for channel id: '.$transfer->{from_channel_id};
            }

            # get relevant web db handle
            my $dbh_web = get_database_handle( { name => 'Web_Live_'.$config_section, type => 'transaction' } );

            eval{
                update_web_stock_level(
                    $handler->dbh,
                    $dbh_web,
                    {
                        quantity_change => ($picked->{$id}{expected_quantity} * -1),
                        variant_id      => $picked->{$id}{variant_id}
                    }
                );
                $dbh_web->commit();
            };

            if($@){
                $dbh_web->rollback();
                die $@;
            }

            $dbh_web->disconnect();

            $handler->schema->resultset('Public::LogPwsStock')->log_stock_change(
                variant_id      => $picked->{$id}{variant_id},
                channel_id      => $transfer->{from_channel_id},
                pws_action_id   => $PWS_ACTION__CHANNEL_TRANSFER_OUT,
                quantity        => ($picked->{$id}{expected_quantity} * -1),
                notes           => 'Channel Transfer Pick',
                operator_id     => $handler->{data}{operator_id},
            );
        }

    }

    # set status of transfer
    set_channel_transfer_status( $handler->dbh, { transfer_id => $handler->{param_of}{transfer_id}, operator_id => $handler->{data}{operator_id}, status_id => $CHANNEL_TRANSFER_STATUS__PICKED } );

    $handler->{data}{redirect}      = '/StockControl/ChannelTransfer?list_type=Picking';
    $handler->{data}{display_msg}   = 'Pick complete for transfer: '.$handler->{param_of}{transfer_id};

    return;

}

1;

