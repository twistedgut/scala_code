package XTracker::Stock::Actions::SetStockAdjustment;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database;
use XTracker::Constants::FromDB qw( :pws_action :stock_action :authorisation_level );
use XTracker::Database::Stock qw( update_quantity delete_quantity check_stock_location get_stock_location_quantity );
use XTracker::Database::Logging qw( log_stock log_location );
use XTracker::Database::Channel qw( get_channels get_channel_details );
use XTracker::Error;

use Try::Tiny;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $product_id  = $handler->{param_of}{product_id} || 0;
    my $variant_id  = $handler->{param_of}{variant_id} || 0;
    my $view_channel= $handler->{param_of}{view_channel} || '';

    my $redirect_url = "/StockControl/StockAdjustment/AdjustStock?product_id=$product_id&variant_id=$variant_id&view_channel=$view_channel";

    if ( $handler->auth_level < $AUTHORISATION_LEVEL__OPERATOR ) {
        xt_warn("You don't have permission to make stock adjustments.");
        return $handler->redirect_to( $redirect_url );
    }

    eval {

        my %variant_data;

        my %changed_locations=();

        # loop over form post and get location data
        # into a format we can use
        foreach my $form_key ( keys %{ $handler->{param_of} } ) {
            # look for three embedded underscores, separated by anything but underscores
            if ( $form_key =~ m/_[^_]+_[^_]+_/ ) {
                my ($field_name,   $variant_id,   $location_id,   $status_id) = split /_/, $form_key;

                if ($field_name && $variant_id && $location_id && $status_id) {
                    $variant_data{ $variant_id }{ $location_id }{ $status_id }{ $field_name } = $handler->{param_of}{$form_key};

                    if ( $field_name eq 'quantity' && $variant_data{ $variant_id }{ $location_id }{ $status_id }{ $field_name } ) {
                        $changed_locations{$location_id} = 1;
                    }
                }
            }
        }

        my $schema = $handler->schema;
        if ($handler->iws_rollout_phase > 0) {
            my $iws_location = $schema->resultset('Public::Location')->get_iws_location;

            if ( $iws_location && exists $changed_locations{$iws_location->id} ) {
                unless ($handler->is_manager) {
                    die "May not update location '".$iws_location->location."'\n";
                }
            }
        }

        # loop over variant data and adjust stock
        foreach my $variant_id ( keys %variant_data ) {
            foreach my $location_id ( keys %{ $variant_data{$variant_id} } ) {
                foreach my $status_id ( keys %{ $variant_data{$variant_id}{$location_id} } ) {

                    next if $variant_data{$variant_id}{$location_id}{$status_id}{quantity} == 0;

                    $schema->txn_do(sub{
                        _adjust_stock($schema, {
                            variant_id       => $variant_id,
                            location_id      => $location_id,
                            status_id        => $status_id,
                            location         => $variant_data{$variant_id}{$location_id}{$status_id}{location},
                            locationquantity => $variant_data{$variant_id}{$location_id}{$status_id}{locationquantity},
                            quantity         => $variant_data{$variant_id}{$location_id}{$status_id}{quantity},
                            reason           => $variant_data{$variant_id}{$location_id}{$status_id}{reason},
                            notes            => $variant_data{$variant_id}{$location_id}{$status_id}{notes},
                            operator_id      => $handler->{data}{operator_id},
                            channel_id       => $variant_data{$variant_id}{$location_id}{$status_id}{channel},
                        });
                    });
                }
            }
        }
        xt_success('Stock successfully adjusted');
    };
    if ($@) {
        xt_warn("An error occured whilst adjusting the stock:<br />$@");
    }

    return $handler->redirect_to( $redirect_url );
}

sub _adjust_stock {
    my ($schema, $argref) = @_;

    # zero-quantity stock adjustment makes no sense - just return
    return unless $argref->{quantity};

    # pre-validation

    # work out adjustment type
    if ( $argref->{quantity} > 0 ) {
        $argref->{adjustment_type}  = 'inc';    # increment
    }
    else {
        $argref->{adjustment_type}  = 'dec';    # decrement
    }

    # verify that current quantity - adjusted quantity doesn't go below 0
    if ( $argref->{adjustment_type} eq 'dec' && ($argref->{locationquantity} - $argref->{quantity}) < 0 ) {
        die "Please ensure adjusted quantity does not exceed current location quantity\n";
    }

    # check that reason was selected
    if ( !$argref->{reason} ) {
        die "Please select a reason\n";
    }

    # check that a note was entered
    if ( !$argref->{notes} ) {
        die "Please enter a note\n";
    }

    # return if no quantity was entered
    if ( $argref->{quantity} eq '' || $argref->{quantity} == 0 ) {
        return;
    }


    # work out stock and pws actions
    my $stock_action    = $STOCK_ACTION__MANUAL_ADJUSTMENT;
    my $pws_action      = $PWS_ACTION__MANUAL_ADJUSTMENT;

    # override defaults for a channel transfer adjustment
    if ($argref->{reason} eq 'Sales Channel Transfer') {
        if ( $argref->{quantity} > 0 ) {
            $stock_action    = $STOCK_ACTION__CHANNEL_TRANSFER_IN;
            $pws_action      = $PWS_ACTION__CHANNEL_TRANSFER_IN;
        }
        else {
            $stock_action    = $STOCK_ACTION__CHANNEL_TRANSFER_OUT;
            $pws_action      = $PWS_ACTION__CHANNEL_TRANSFER_OUT;
        }
    }

    my $dbh = $schema->storage->dbh;

    # update quantity record
    update_quantity(
        $dbh,
        {
            variant_id  => $argref->{variant_id},
            location    => $argref->{location},
            quantity    => $argref->{quantity},
            type        => $argref->{adjustment_type},
            channel_id  => $argref->{channel_id},
            current_status_id => $argref->{status_id},
         }
    );

    # log update
    log_stock(
        $dbh,
        {
            variant_id  => $argref->{variant_id},
            action      => $stock_action,
            quantity    => $argref->{quantity},
            operator_id => $argref->{operator_id},
            notes       => $argref->{notes},
            channel_id  => $argref->{channel_id},
        },
    );


    # delete quantity record if location now empty
    my $old_quantity = get_stock_location_quantity(
        $dbh,
        {   variant_id  => $argref->{variant_id},
            location    => $argref->{location},
            channel_id  => $argref->{channel_id},
            status_id => $argref->{status_id},
        }
    );
    if ( $old_quantity == 0 ) {
        delete_quantity(
            $dbh,
            {
                variant_id  => $argref->{variant_id},
                location    => $argref->{location},
                channel_id  => $argref->{channel_id},
                status_id => $argref->{status_id},
            }
        );

        log_location(
            $dbh,
            {
                variant_id  => $argref->{variant_id},
                location_id => $argref->{location_id},
                operator_id => $argref->{operator_id},
                channel_id  => $argref->{channel_id}
             }
        );
    }



    # get sales channel info
    my $config_section  = '';
    my $channels        = get_channels( $dbh );
    foreach my $channel_id ( keys %$channels) {
        if ( $channel_id == $argref->{channel_id}) {
            $config_section = $channels->{$channel_id}{config_section};
        }
    }

    if (!$config_section) {
        die 'Unable to get channel config section for channel id: '.$argref->{channel_id};
    }

    my $stock_manager = XTracker::WebContent::StockManagement->new_stock_manager({
        schema      => $schema,
        channel_id  => $argref->{channel_id},
    });

    try {
        $stock_manager->stock_update(
            quantity_change     => $argref->{quantity},
            variant_id          => $argref->{variant_id},
            skip_non_live       => 1,
            operator_id         => $argref->{operator_id},
            pws_action_id       => $pws_action,
            notes               => $argref->{notes},
        );

        $stock_manager->commit();
    }
    catch {
        $stock_manager->rollback();
        die $_;
    };

    $stock_manager->disconnect();

    return;
}

1;
