package XTracker::Stock::Actions::PutawayChannelTransfer;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database                  qw( get_database_handle );
use XTracker::Database::ChannelTransfer qw( create_channel_transfer_putaway get_channel_transfer get_channel_transfer_pick get_channel_transfer_putaway set_channel_transfer_status cancel_channel_transfer_putaway set_product_transfer_status );
use XTracker::Database::Product         qw( product_present );
use XTracker::Database::Stock           qw( update_quantity insert_quantity get_stock_location_quantity set_stock_count update_stock_count set_stock_summary );
use XTracker::Database::Logging         qw( log_stock log_location );
use XTracker::Database::Channel         qw( get_channels get_channel_details );

use XTracker::Comms::FCP                qw( update_web_stock_level );
use XTracker::Utilities                 qw( url_encode );
use XTracker::Constants::FromDB         qw( :channel_transfer_status :pws_action :stock_action :stock_count_origin :stock_count_status :product_channel_transfer_status :flow_status );
use XTracker::Config::Local             qw( config_var );
use XT::JQ::DC;
use XTracker::Error;
use XTracker::WebContent::StockManagement::Broadcast;

use DateTime;

sub handler {
    my $handler     = XTracker::Handler->new(shift);
    my $error_msg   = '';
    my $status_msg  = '';
    my $view        = $handler->{param_of}{view};
    my $transfer_id = $handler->{param_of}{transfer_id};

    eval {

        my $guard = $handler->schema->txn_scope_guard;
        # putaway recorded
        if ( $handler->{param_of}{action} eq 'Putaway' ) {
            _record_putaway($handler);
        }

        # Cancel putaway
        if ( $handler->{param_of}{action} eq 'Cancel' ) {
            _cancel_putaway($handler);
        }

        # Complete putaway
        if ( $handler->{param_of}{action} eq 'Complete' ) {
            _complete_putaway($handler);
        }

        $guard->commit();
    };

    if ($@) {
        $@ =~ s/at \/opt\/xt\/.*//;
        xt_warn("An error occured:<br />$@");
        $handler->{data}{redirect} = '/StockControl/ChannelTransfer/Putaway?transfer_id='.$handler->{param_of}{transfer_id};
    }

    xt_success($handler->{data}{display_msg}) if $handler->{data}{display_msg};
    my $redirect_url = $handler->{data}{redirect} . '&view='.$view;

    return $handler->redirect_to( $redirect_url );

}


sub _record_putaway {

    my ( $handler ) = @_;

    my $schema      = $handler->{schema};

    # get transfer info
    my $transfer    = get_channel_transfer( $handler->{dbh}, { transfer_id => $handler->{param_of}{transfer_id} } );

    # get location info for location
    my $location = eval {
        $handler->{schema}->resultset('Public::Location')->get_location({
                                                       location => $handler->{param_of}{putaway_location},
                                                    });
    };
    die "The location entered could not be found. Please try again."
        unless $location;
    die "The location entered was not a valid main stock location."
        unless $location->allows_status($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS);

    create_channel_transfer_putaway(
        $handler->{dbh},
        {
            transfer_id => $handler->{param_of}{transfer_id},
            variant_id  => $handler->{param_of}{variant_id},
            location_id => $location->id,
            quantity    => $handler->{param_of}{putaway_quantity},
            operator_id => $handler->{data}{operator_id},
        }
    );

    $handler->{data}{redirect}      = '/StockControl/ChannelTransfer/Putaway?transfer_id='.$handler->{param_of}{transfer_id};
    $handler->{data}{display_msg}   = 'Putaway recorded';

    return;

}

sub _cancel_putaway {

    my ( $handler ) = @_;

    cancel_channel_transfer_putaway(
        $handler->{dbh},
        {
            transfer_id         => $handler->{param_of}{transfer_id},
            operator_id         => $handler->{data}{operator_id},
        }
    );

    $handler->{data}{redirect}      = '/StockControl/ChannelTransfer/Putaway?transfer_id='.$handler->{param_of}{transfer_id};
    $handler->{data}{display_msg}   = 'Putaway cancelled';

    return;

}


sub _complete_putaway {

    my ( $handler ) = @_;

    # get all pick records and decrement stock
    my $transfer    = get_channel_transfer( $handler->{dbh}, { transfer_id => $handler->{param_of}{transfer_id} } );
    my $picked      = get_channel_transfer_pick( $handler->{dbh}, { transfer_id => $handler->{param_of}{transfer_id} } );
    my $putaway     = get_channel_transfer_putaway( $handler->{dbh}, { transfer_id => $handler->{param_of}{transfer_id} } );

    my $total_quantity = 0;

    # first we want a hash of variants and the total quantity picked
    my %picked = ();
    foreach my $id ( keys %{$picked} ) {
        $picked{ $picked->{$id}{variant_id} }{expected_quantity}    += $picked->{$id}{expected_quantity};
        $picked{ $picked->{$id}{variant_id} }{picked_quantity}      += $picked->{$id}{picked_quantity};

        $total_quantity += $picked{ $picked->{$id}{variant_id} }{expected_quantity};
    }

    my %putaway_total = ();

    # now work out what to putaway where
    foreach my $id ( keys %{$putaway} ) {

        my $discrep_expected    = 0;
        my $discrep_counted     = 0;
        my $variant_id          = $putaway->{$id}{variant_id};
        my $quantity            = $putaway->{$id}{quantity};

        $putaway_total{$variant_id}{current} += $putaway->{$id}{quantity};

    # quick check that they haven't put away more than they picked
        if ( $putaway_total{$variant_id}{current} > $picked{ $variant_id }{picked_quantity} ){
            die 'Putaway quantity is greater than the picked quantity, please check and try again.'
        }

        # this is a bit weird but we want to ultimately transfer the 'expected' quantities
        # rather than the 'picked' quantities to keep things clean
        # a variance will be recorded against the new location after putaway if
        # expected qty did not match picked qty
        if ( $picked{ $variant_id }{expected_quantity} != $picked{ $variant_id }{picked_quantity} && $picked{ $variant_id }{picked_quantity} == $putaway_total{$variant_id}{current} ) {
            if ( $putaway_total{$variant_id}{running} ) {
                $quantity   = $picked{ $variant_id }{expected_quantity} - $putaway_total{$variant_id}{running};
            }
            else {
                $quantity = $picked{ $variant_id }{expected_quantity};
            }

            $discrep_expected   = $quantity;
            $discrep_counted    = $putaway->{$id}{quantity};
        }

        $putaway_total{$variant_id}{running} += $putaway->{$id}{quantity};

        # check if insert or update on quantity
        my $cur_quantity = get_stock_location_quantity(
            $handler->{dbh},
            {
                variant_id  => $variant_id,
                location    => $putaway->{$id}{location},
                channel_id  => $transfer->{to_channel_id},
                status_id   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            }
        );

        if ( $cur_quantity ) {
            # update quantity record
            # NOTE: this never actually happens
            # Why? Because:
            # 1) a product belongs to a business
            # 2) a "channel transfer" within a DC is a business transfer
            # 3) so we can't have stock on more than 1 channel for the
            #    same product or variant
            # 4) so there can't be a quantity record for the
            #    destination channel and the variant we are moving
            update_quantity(
                $handler->{dbh},
                {
                    variant_id  => $variant_id,
                    location    => $putaway->{$id}{location},
                    quantity    => $quantity,
                    type        => 'inc',
                    channel_id  => $transfer->{to_channel_id},
                    current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                    next_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                 }
            );
        }
        else {
            insert_quantity(
                $handler->{dbh},
                {
                    variant_id  => $variant_id,
                    location    => $putaway->{$id}{location},
                    quantity    => $quantity,
                    channel_id  => $transfer->{to_channel_id},
                    initial_status_id   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                 }
            );
        }

        # log update
        log_stock(
            $handler->{dbh},
            {
                variant_id  => $variant_id,
                action      => $STOCK_ACTION__CHANNEL_TRANSFER_IN,
                quantity    => $quantity,
                operator_id => $handler->{data}{operator_id},
                notes       => 'Channel Transfer Putaway',
                channel_id  => $transfer->{to_channel_id},
            },
        );

        # record a PI variance if discrep found
        if ( $discrep_expected || $discrep_counted ) {
            my $count_id = set_stock_count(
                                $handler->{dbh},
                                {
                                        variant_id    => $variant_id,
                                        location      => $putaway->{$id}{location},
                                        round         => 1,
                                        cur_stock     => $discrep_expected,
                                        count         => $discrep_counted,
                                        operator_id   => $handler->{data}{operator_id},
                                        group         => undef,
                                        origin_id     => $STOCK_COUNT_ORIGIN__CHANNEL_TRANSFER
                                }
            );

            update_stock_count( $handler->{dbh}, { status_id => $STOCK_COUNT_STATUS__PENDING_INVESTIGATION, type => 'id', type_id => $count_id });
        }

        # adjust website if product is live
        if ( product_present( $handler->{dbh}, { type => 'variant_id', id => $variant_id, channel_id => $transfer->{to_channel_id} } ) ) {

            # get sales channel info
            my $config_section  = '';
            my $channels        = get_channels( $handler->{dbh} );
            foreach my $channel_id ( keys %$channels) {
                if ( $channel_id == $transfer->{to_channel_id}) {
                    $config_section = $channels->{$channel_id}{config_section};
                }
            }

            if (!$config_section) {
                die 'Unable to get channel config section for channel id: '.$transfer->{to_channel_id};
            }

            # get relevant web db handle
            my $dbh_web = get_database_handle( { name => 'Web_Live_'.$config_section, type => 'transaction' } );

            eval{
                update_web_stock_level(
                    $handler->{dbh},
                    $dbh_web,
                    {
                        quantity_change => $quantity,
                        variant_id      => $variant_id
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
                variant_id      => $variant_id,
                channel_id      => $transfer->{to_channel_id},
                pws_action_id   => $PWS_ACTION__CHANNEL_TRANSFER_IN,
                quantity        => $quantity,
                notes           => 'Channel Transfer Putaway',
                operator_id     => $handler->{data}{operator_id},
            );
        }

    }

    # set status of transfer
    set_channel_transfer_status( $handler->{dbh}, { transfer_id => $handler->{param_of}{transfer_id}, operator_id => $handler->{data}{operator_id}, status_id => $CHANNEL_TRANSFER_STATUS__COMPLETE } );


    # set product transfer status on source channel
    my $dt = DateTime->now(time_zone => "local");
    set_product_transfer_status(
        $handler->{dbh},
        {
            product_id  => $transfer->{product_id},
            channel_id  => $transfer->{from_channel_id},
            status_id   => $PRODUCT_CHANNEL_TRANSFER_STATUS__TRANSFERRED,
            operator_id => $handler->{data}{operator_id},
            transfer_date   => $dt->date,
        }
    );

    # set ordered quantity as qty transferred on dest channel
    if ( $total_quantity ){
        set_stock_summary(
            $handler->{dbh},
            {
                product_id  => $transfer->{product_id},
                channel_id  => $transfer->{to_channel_id},
                field       => 'ordered',
                value       => $total_quantity,
            }
        );
    }

    # tell Product Service
    my $broadcast = XTracker::WebContent::StockManagement::Broadcast->new({
        schema => $handler->schema,
        channel_id => $transfer->{from_channel_id},
    });
    $broadcast->stock_update(
        quantity_change => 0,
        product_id => $transfer->{product_id},
    );
    $broadcast->commit();
    $broadcast = XTracker::WebContent::StockManagement::Broadcast->new({
        schema => $handler->schema,
        channel_id => $transfer->{to_channel_id},
    });
    $broadcast->stock_update(
        quantity_change => 0,
        product_id => $transfer->{product_id},
    );
    $broadcast->commit();

    # Tell PRLs about it
    my $product = $handler->{schema}->resultset('Public::Product')->find($transfer->{product_id});
    if ($product) {
        $product->discard_changes;
        $product->send_sku_update_to_prls({'amq'=>$handler->msg_factory});
    }

    # create fulcrum 'transfer complete' job

    my %fulcrum_payload = (
        source_channel  => $transfer->{from_channel_id},
        dest_channel    => $transfer->{to_channel_id},
        transfer_date   => $dt->date,
        product_id      => $transfer->{product_id},
        quantity        => $total_quantity,
    );

    my $job = XT::JQ::DC->new({ funcname => 'Send::Product::Transfered' });
    $job->set_payload( \%fulcrum_payload );
    $job->send_job();


    $handler->{data}{redirect}      = '/StockControl/ChannelTransfer?list_type=Putaway';
    $handler->{data}{display_msg}   = 'Putaway complete for transfer: '.$handler->{param_of}{transfer_id};

    return;

}

1;

