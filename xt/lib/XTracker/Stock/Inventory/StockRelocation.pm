package XTracker::Stock::Inventory::StockRelocation;

use strict;
use warnings;

use Try::Tiny;

use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Error;
use XTracker::Handler;

use XTracker::Database::Location qw( get_stock_in_location :iws );
use XTracker::Database::Channel  qw( get_channels );
use XTracker::Utilities qw( :string );

################################################################
#
# Change for DCEA-499
#
# Previously, in theory, zero items of stock could be moved
# to a new location with this handler.  Now that we use
# ::Quantity->move_stock() to do the move, that is no longer
# allowed; only those items of stock in the source location
# that are non-zero actually get moved -- the zero-valued
# items are quietly left behind in the original location
# That shouldn't matter, since it's not as if they're
# taking up space.
#
# It's unlikely that this functional change affects anything,
# but it is a change, and so I'm drawing attention to it here.
#
#

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {
    # get a handler
    my $handler = XTracker::Handler->new( shift );

    # form input
    my ($from_location, $to_location, $view ) = trim( @{$handler->{param_of}}{ qw( from_location to_location view ) } );

    # form data
    $handler->{data}{from_location} = $from_location;
    $handler->{data}{to_location}   = $to_location;
    $handler->{data}{view}          = $view;

    $handler->{data}{content}       = 'stocktracker/inventory/stock_relocation.tt';
    $handler->{data}{section}       = 'Inventory';
    $handler->{data}{subsection}    = 'Stock Relocation';

    try {
        # if 'from' location entered get list of stock for that location (needs to have stock)
        if ( $handler->{data}{from_location} ) {
            if (matches_iws_location($from_location)) {
                $handler->{data}{from_location} = '';

                die "Stock may not be moved from location '$from_location'\n";
            }

            $handler->{data}{stock}         = get_stock_in_location( $handler->dbh, $handler->{data}{from_location} );

            unless (@{$handler->{data}{stock}}) {
                my $from_location = $handler->{data}{from_location};

                $handler->{data}{from_location} = '';

                die "No stock could be found in location: $from_location\n";
            }
        }

        # if 'to' location entered check if it have stock - HAS to be empty to proceed
        if ( $handler->{data}{to_location} ) {
            if (matches_iws_location($to_location)) {
                die "Stock may not be moved to location '$to_location'\n";
            }

            $handler->{data}{to_stock}          = get_stock_in_location( $handler->dbh, $handler->{data}{to_location} );

            # if have stock give user feedback and empty value of to_location to allow another to be entered
            if (@{$handler->{data}{to_stock}}) {
                my $to_location = $handler->{data}{to_location};
                die "Location $to_location contains stock, please enter an empty location\n";
            }
            else {
                # Get Sales Channels
                my $channel_by_id   = get_channels($handler->dbh);
                my %channel_by_name;

                foreach ( keys %$channel_by_id ) {
                    $channel_by_name{$channel_by_id->{$_}{name}} = $_;
                }

                # check that all the stock in this location is movable to the new location
                my $quantity_rs=$handler->{schema}->resultset('Public::Quantity');
                my @validation_errors=();

            STOCK_ITEM:
               foreach my $stock_item (@{$handler->{data}{stock}}) {
                   next STOCK_ITEM unless $stock_item->{quantity};

                   eval {
                        my $channel_id=$channel_by_name{$stock_item->{sales_channel}};

                        $quantity_rs->validate_move_stock({
                            variant => $stock_item->{id},
                            channel => $channel_id,
                            quantity => $stock_item->{quantity},
                            from => {
                                location => $handler->{data}{from_location},
                                status   => $stock_item->{status_id}
                            },
                            to => {
                                location => $handler->{data}{to_location},
                                status   => $stock_item->{status_id}
                            },
                        });
                    };

                    push @validation_errors,$@ if $@;
                }

                die join('; ',@validation_errors)."\n" if @validation_errors;
            }
        }
    }
    catch {
        $handler->{data}{to_location}   = '';
        xt_warn($_);
    };

    $handler->process_template( undef );

    return OK;
}


1;

__END__
