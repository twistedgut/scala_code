package XTracker::Stock::Actions::CreateReservation;

use strict;
use warnings;

use Data::Dump qw(pp);

use XTracker::Handler;
use XTracker::Constants::FromDB qw( :customer_category );
use XTracker::Database::Customer qw( check_or_create_customer );
use XTracker::Database::Reservation qw( create_reservation );
use XTracker::Database::Channel qw( get_channel_details );
use XTracker::Error;
use XTracker::WebContent::StockManagement;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    # set up vars to store user responses
    my $response    = '';
    my $error       = '';

    # form submitted
    if ( $handler->{param_of}{is_customer_number} ){
        eval {

            my $schema = $handler->schema;
            my $dbh = $schema->storage->dbh;

            my $guard = $schema->txn_scope_guard;
            # get correct web handle for channel
            my $channel_info = get_channel_details( $dbh, $handler->{param_of}{channel} );

            die 'Unable to get channel config section for channel: '.$handler->{param_of}{channel}
                if !$channel_info->{config_section};

            my $stock_manager
                = XTracker::WebContent::StockManagement->new_stock_manager({
                schema => $schema,
                channel_id => $channel_info->{id},
            });

            eval {
                # Create a customer if it exists in XT but not on PWS (no
                # customer_id passed)
                my %args = (
                    is_customer_number => $handler->{param_of}{is_customer_number},
                    first_name         => $handler->{param_of}{first_name},
                    last_name          => $handler->{param_of}{last_name},
                    email              => $handler->{param_of}{email},
                    account_urn        => $handler->{param_of}{account_urn},
                    channel_id         => $channel_info->{id},
                );
                $args{customer_id} = $handler->{param_of}{customer_id}
                                  // check_or_create_customer($dbh, {
                                         %args,
                                         category_id => $CUSTOMER_CATEGORY__NONE,
                                     });
                # create_reservation takes is_customer_number as customer_nr
                $args{customer_nr} = delete $args{is_customer_number};
                my $reservation_id = create_reservation( $dbh, $stock_manager, {
                    %args,
                    channel       => $handler->{param_of}{channel},
                    variant_id    => $handler->{param_of}{variant_id},
                    operator_id   => $handler->{data}{operator_id},
                    department_id => $handler->{data}{department_id},
                    reservation_source_id => $handler->{param_of}{reservation_source_id},
                    reservation_type_id => $handler->{param_of}{reservation_type_id},
                });

                $stock_manager->commit();
            };
            if ( my $err = $@ ) {
                $stock_manager->rollback();
                die $err;
            }

            $stock_manager->disconnect();
            $guard->commit();
        };

        if ( my $err = $@ ) {
            $error = "An error occured whilst trying to create the reservation: $err";
        }
        else {
             $response = 'Reservation successfully created for customer '
                       . $handler->{param_of}{is_customer_number}
                       . ', '
                       . $handler->{param_of}{first_name}
                       . ' '
                       . $handler->{param_of}{last_name};
        }
    }
    xt_warn($error) if $error;
    xt_success($response) if $response;
    return $handler->redirect_to( $handler->{param_of}{redirect_url} || '/StockControl/Reservation' );
}

1;
