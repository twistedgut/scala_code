package XTracker::Stock::Actions::UpdateReservation;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Reservation qw( get_reservation_details upload_reservation cancel_reservation edit_reservation );
use XTracker::Database::Channel qw( get_channel_details );
use XTracker::WebContent::StockManagement;
use XTracker::Error;

sub handler {
    ## no critic(ProhibitDeepNests)
    my $handler     = XTracker::Handler->new(shift);

    # set up vars to store user responses
    my $response    = '';
    my $error       = '';

    my $auth_err_message = "Unable to update reservation changes as reservation belongs to 'Personal Shopper/Fashion Advisor'";

    # Get logged in operator
    my $operator = $handler->operator;
    my $schema   = $handler->schema;

    # form submitted
    if ( $handler->{param_of}{action} ){
        eval {

            my $schema = $handler->schema;
            my $dbh = $schema->storage->dbh;
            # updating via list - multiple actions
            if ($handler->{param_of}{action} eq 'Edit_Delete'){
                foreach my $form_key ( %{$handler->{param_of}} ) {
                    if ($form_key =~ m/delete-/ || $form_key =~ m/expiry-/) {
                        my ($action, $reservation_id) = split(/-/, $form_key);

                        # check too see, if logged in operator is allowed to edit reservation
                        die ( $auth_err_message ) unless _is_allowed_to_edit_reservation( $schema, {
                            operator        => $operator,
                            reservation_id  => $reservation_id
                        } );


                        $handler->{param_of}{special_order_id} = $reservation_id;

                        # get info for reservation up front
                        my $info = get_reservation_details( $dbh, $handler->{param_of}{special_order_id} );

                        # get correct web handle for channel
                        my $channel_info = get_channel_details( $dbh, $info->{sales_channel} );
                        if ( !$channel_info->{config_section} ) {
                            die 'Unable to get channel config section for channel: '.$info->{sales_channel};
                        }
                        # get a new Stock Management object to connect to the Web DB which is used to Update Stock Levels
                        my $stock_manager   = XTracker::WebContent::StockManagement->new_stock_manager( {
                            schema      => $schema,
                            channel_id  => $channel_info->{id},
                        } );

                        eval{
                            my $guard = $schema->txn_scope_guard;
                            # updating expiry date
                            if ( $action eq 'expiry' && ( $handler->{param_of}{'original_expiry_'.$reservation_id } // '' ) ne $handler->{param_of}{$form_key} ) {

                                # get info out of form value
                                ($handler->{param_of}{'expireDay'}, $handler->{param_of}{'expireMonth'}, $handler->{param_of}{'expireYear'}) = split(/-/, $handler->{param_of}{$form_key});


                                # update expiry if a day month and year defined
                                if ( $handler->{param_of}{'expireDay'} =~ m/\d{2}/
                                  && $handler->{param_of}{'expireMonth'} =~ m/\d{2}/
                                  && $handler->{param_of}{'expireYear'} =~ m/\d{4}/ ) {
                                    edit_reservation(
                                        $schema,
                                        $stock_manager,
                                        $channel_info->{id},
                                        $handler->{param_of}
                                    );
                                }
                                else {
                                    die 'Incorrect date format entered: '.$handler->{param_of}{$form_key};
                                }
                            }
                            # deleting
                            if ($action eq 'delete' && $handler->{param_of}{$form_key} == 1) {
                                cancel_reservation(
                                    $dbh,
                                    $stock_manager,
                                    {
                                        reservation_id  => $handler->{param_of}{special_order_id},
                                        status_id       => $info->{status_id},
                                        variant_id      => $info->{variant_id},
                                        operator_id     => $handler->{data}{operator_id},
                                        customer_nr     => $info->{is_customer_number}
                                    }
                                );
                            }

                            $stock_manager->commit();
                            $guard->commit();
                        };
                        if ( my $err = $@ ) {
                            $stock_manager->rollback();
                            die $err;
                        }
                        $stock_manager->disconnect();
                    }
                }
            }
            # single update from product page
            else {

                # check if logged in operator is allowed to edit reservation
                die ( $auth_err_message ) unless _is_allowed_to_edit_reservation( $schema, {
                    reservation_id => $handler->{param_of}{special_order_id},
                    operator => $operator
                } );

                # get info for reservation up front
                my $info = get_reservation_details( $dbh, $handler->{param_of}{special_order_id} );

                # get correct web handle for channel
                my $channel_info = get_channel_details( $dbh, $info->{sales_channel} );
                if ( !$channel_info->{config_section} ) {
                    die 'Unable to get channel config section for channel: '.$info->{sales_channel};
                }

                # get a new Stock Management object to connect to the Web DB which is used to Update Stock Levels
                my $stock_manager   = XTracker::WebContent::StockManagement->new_stock_manager( {
                    schema      => $schema,
                    channel_id  => $channel_info->{id},
                } );
                eval{
                    my $guard = $schema->txn_scope_guard;
                    # uploading a reservation
                    if ($handler->{param_of}{action} eq 'Upload'){
                        upload_reservation(
                            $dbh,
                            $stock_manager,
                            {
                                reservation_id  => $handler->{param_of}{special_order_id},
                                variant_id      => $info->{variant_id},
                                operator_id     => $handler->{data}{operator_id},
                                customer_id     => $info->{customer_id},
                                customer_nr     => $info->{is_customer_number},
                                channel_id      => $channel_info->{id},
                            }
                        );
                    }
                    # deleting a reservation
                    elsif ($handler->{param_of}{action} eq 'Delete'){
                        cancel_reservation(
                            $dbh,
                            $stock_manager,
                            {
                                reservation_id  => $handler->{param_of}{special_order_id},
                                status_id       => $info->{status_id},
                                variant_id      => $info->{variant_id},
                                operator_id     => $handler->{data}{operator_id},
                                customer_nr     => $info->{is_customer_number}
                            }
                        );
                    }
                    # editing a reservation
                    elsif ($handler->{param_of}{action} eq 'Edit'){
                        edit_reservation(
                            $schema,
                            $stock_manager,
                            $channel_info->{id},
                            $handler->{param_of}
                        );
                    }

                    $stock_manager->commit();
                    $guard->commit();
                };
                if ( my $err = $@ ) {
                    $stock_manager->rollback();
                    die $err;
                }
                $stock_manager->disconnect();
            }
        };

        if ( my $err = $@ ) {
            $error = "An error occured whilst trying to update the reservation: $err";
        }
        else {
            $response = 'Reservation successfully updated.';
        }
    }

    xt_success($response) if $response;
    xt_warn($error) if $error;
    return $handler->redirect_to( $handler->{param_of}{redirect_url} )
}

=head2 _is_allowed_to_edit_reservation

   $boolean = _is_allowed_to_edit_reservation( $schema, {
                reservation_id => '123',
                operator       => <operator_obj>
              } );

Returns TRUE if the given operator is allowed to edit the reservation
else return FALSE.

=cut

sub _is_allowed_to_edit_reservation {
    my $schema = shift;
    my $args   = shift;

    my $operator        = $args->{ operator } ;
    my $reservation_id  = $args->{ reservation_id };


    my $reservation = $schema->resultset('Public::Reservation')->find( $reservation_id );

    if ( $reservation && $reservation->can_edit_reservation( $operator ) ) {
        return 1;
    }

    return 0;
}

1;
