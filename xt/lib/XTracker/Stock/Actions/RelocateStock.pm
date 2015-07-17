package XTracker::Stock::Actions::RelocateStock;

use strict;
use warnings;

use XTracker::Error qw( xt_warn xt_success );
use XTracker::Handler;
use XTracker::Database qw( :common );

use XTracker::Database::Location qw( get_stock_in_location :iws );
use XTracker::Database::Channel qw( get_channels );
use XTracker::Utilities qw( :string );

sub handler {
    my $handler = XTracker::Handler->new( shift );

    # form input
    my ($from_location, $to_location, $view) = trim( @{$handler->{param_of}}{ qw( from_location to_location view ) } );

    if ( $from_location && $to_location ) {
        eval {
            die "Stock may not be moved from location '$from_location'\n"
                if matches_iws_location($from_location);

            die "Stock may not be moved to location '$to_location'\n"
                if matches_iws_location($to_location);

            my $dbh = $handler->dbh;

            my $channel_by_id       = get_channels($dbh);
            my %channel_by_name;

            foreach ( keys %$channel_by_id ) {
                $channel_by_name{$channel_by_id->{$_}{name}} = $_;
            }

            my $location_stock = get_stock_in_location( $dbh, $from_location );

            my $schema = $handler->schema;

            $schema->txn_do(
                sub {
                    # Quantity implements move_stock operation
                    my $quantity_rs=$schema->resultset('Public::Quantity');

                    STOCK_ITEM:
                    foreach my $stock_item (@{$location_stock}) {

                        # because we can't relocate negative stock
                        next STOCK_ITEM unless $stock_item->{quantity} > 0;

                        my $channel_id  = $channel_by_name{$stock_item->{sales_channel}};

                        $quantity_rs->move_stock({
                            variant => $stock_item->{id},
                            channel => $channel_id,
                            quantity => $stock_item->{quantity},
                            from => {
                                location => $from_location,
                                status   => $stock_item->{status_id}
                            },
                            to => {
                                location => $to_location,
                                status   => $stock_item->{status_id}
                            },
                            log_location_as => $handler->operator_id,
                        });
                    }
                }
            );
        };

        if ($@) {
            xt_warn(strip_txn_do($@));
        }
        else {
            xt_success('Stock relocation completed successfully');
        }
    }
    else {
        xt_warn('No locations provided');
    }

    my $redirect  = '/StockControl/StockRelocation?view=';      # where to send the user back to
    $redirect    .= 'HandHeld' if $view;

    return $handler->redirect_to( $redirect );
}

1;
