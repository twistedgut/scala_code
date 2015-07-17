package XTracker::Stock::Reservation::Create;

use strict;
use warnings;

use Data::Dump qw(pp);

use XTracker::Handler;
use XTracker::Database;
use XTracker::Database::Channel qw(get_channel_details);
use XTracker::Database::Customer qw(get_customer_from_pws get_customer_from_pws_by_email);
use XTracker::Database::Product qw( get_variant_details :DEFAULT );
use XTracker::Database::Reservation qw( :DEFAULT can_reserve );
use XTracker::Database::Stock;
use XTracker::Error;
use XTracker::Navigation;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Create';
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'stocktracker/reservation/create.tt';

    # build side nav
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'reservations', res_filter => 'Personal' } );

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    my $reserv_source_rs    = $schema->resultset('Public::ReservationSource');
    my $reserv_type_rs      = $schema->resultset('Public::ReservationType');

    # Redirect to the product search page unless we have a variant
    return $handler->redirect_to( '/StockControl/Reservation/Product' )
        unless $handler->{param_of}{variant_id};

    $handler->{data}{variant_id}    = $handler->{param_of}{variant_id};
    $handler->{data}{sales_channel} = $handler->{param_of}{channel};
    $handler->{data}{override_pws_customer_check} = $handler->{param_of}{override_pws_customer_check};

    $handler->{data}{variant}       = get_variant_details( $dbh, $handler->{data}{variant_id} );
    $handler->{data}{product}       = get_product_data( $dbh, { type => 'variant_id', id => $handler->{data}{variant_id} });
    $handler->{data}{channel}       = get_channel_details( $dbh, $handler->{data}{sales_channel} );
    $handler->{data}{can_reserve}   = can_reserve( $handler->{dbh}, $handler->{data}{department_id}, $handler->{data}{product}{id} );

    # get the Reservation Source list
    $handler->{data}{reservation_source_list}   = [ $reserv_source_rs->active_list_by_sort_order->all ];
    $handler->{data}{reservation_type_list}     = [ $reserv_type_rs->list_by_sort_order->all ];
    $handler->{data}{reservation_source}        = $handler->{param_of}{reservation_source};
    $handler->{data}{reservation_type}          = $handler->{param_of}{reservation_type};

    # back link for sidenav
    $handler->{data}{sidenav}[0]{'None'}[0] = {
        title => "Back to Product",
        url => "/StockControl/Reservation/Product?product_id=$handler->{data}{product}{id}",
    };

    # can we reserve a product (if not, warn the user and stop processing the page)?
    unless( $handler->{data}{can_reserve}{ $handler->{data}{sales_channel} } ) {
        xt_warn( 'Insufficient permissions - It is not possible to create reservations on pre-uploaded SKU(s).' );
        return $handler->process_template;
    }

    if ( grep { $handler->{param_of}{$_} } qw{is_customer_number email} ) {
        my $is_customer_number = $handler->{param_of}{is_customer_number};
        # Validate customer number
        if ( $is_customer_number and $is_customer_number !~ m{^\s*\d+\s*$} ) {
            xt_warn("The customer number('$is_customer_number') you have entered is not valid");
            return $handler->process_template;
        }

        if ( !$handler->{data}{reservation_source} || $handler->{data}{reservation_source} !~ m/^\d+$/ ) {
            $handler->{data}{input_is_customer_number}  = $is_customer_number;
            $handler->{data}{input_email}               = $handler->{param_of}{email};
            xt_warn("You MUST Select a Source for the Reservation");
            return $handler->process_template;
        }

        if ( !$handler->{data}{reservation_type} || $handler->{data}{reservation_type} !~ m/^\d+$/ ) {
            $handler->{data}{input_is_customer_number}  = $is_customer_number;
            $handler->{data}{input_email}               = $handler->{param_of}{email};
            $handler->{data}{reservation_source}        = $handler->{param_of}{reservation_source};
            xt_warn("You MUST Select a Type for the Reservation");
            return $handler->process_template;
        }
        my %params
            = $is_customer_number
            ? (
                arg            => $is_customer_number,
                search_xt_sub  => 'search_by_pws_customer_nr',
                search_pws_sub => sub { get_customer_from_pws(@_) },
                feedback       => "(id: $is_customer_number)", )
            : (
                arg            => $handler->{param_of}{email},
                search_xt_sub  => 'search_by_email',
                search_pws_sub => sub { get_customer_from_pws_by_email(@_) },
                feedback       => "(email: $handler->{param_of}{email})", )
            ;

        # Check if customer exists in XT
        my $sub = $params{search_xt_sub};
        $handler->{data}{customer}
            = $schema->resultset('Public::Customer')
                    ->$sub( $params{arg} )
                    ->search({ channel_id => $handler->{data}{channel}{id} })
                    ->slice(0,0)
                    ->single;

        # To display the Reservation Source chosen
        $handler->{data}{reservation_source_obj}    = $schema->resultset('Public::ReservationSource')
                                                                ->find( $handler->{data}{reservation_source} );

        $handler->{data}{reservation_type_obj}    = $schema->resultset('Public::ReservationType')
                                                                ->find( $handler->{data}{reservation_type} );

        unless ($handler->{data}{override_pws_customer_check}) {
          if ( $handler->{data}{customer} ) {
            # Validate XT customer number exists on PWS

            my $dbh_web = get_pws_dbh( $dbh, $handler->{param_of}{channel} );
            my $pws_customer_check
                = get_customer_from_pws ( $dbh_web, $handler->{data}{customer}->is_customer_number );
            $dbh_web->disconnect;


            if ( !$pws_customer_check ) {

                if ($is_customer_number) {
                    xt_warn( "Unable to find customer number $is_customer_number for $handler->{data}{sales_channel}.
                        You may have the wrong customer number for this channel.");
                } else {
                    xt_warn( "Unable to find customer email $handler->{param_of}{email} for $handler->{data}{sales_channel}.
                        Please create the reservation using the customer number. You can use the 'Customer Search' facility to help you find the number." );
                }

                $handler->{data}{customer} = undef;
            }

          } else {
            # Check if customer exists on PWS

            my $dbh_web = get_pws_dbh( $dbh, $handler->{param_of}{channel} );
            $handler->{data}{pws_customer}
                = $params{search_pws_sub}->( $dbh_web, $params{arg} );
            $dbh_web->disconnect;

            # Give user feedback on whether we did or didn't find the customer
            # on the website
            if ( $handler->{data}{pws_customer} ) {
                xt_info("Customer $params{feedback} does not exist in XT.
                    Continuing with the reservation will create the customer
                    with data retrieved from
                    $handler->{data}{sales_channel}.");
            }
            else {
                xt_warn( "Could not find customer $params{feedback}. Customer
                    must first be registered on
                    $handler->{data}{sales_channel} before a reservation can
                    be made." );
            }
        }
      }
    }
    return $handler->process_template;
}

sub get_pws_dbh {
    my ( $dbh, $channel ) = @_;
    my $channel_info = get_channel_details( $dbh, $channel );

    die "Unable to get channel config section for channel: $channel"
        unless $channel_info->{config_section};

    # get relevant web db handle
    return XTracker::Database::get_database_handle({
        name => "Web_Live_$channel_info->{config_section}",
        type => 'readonly',
    });
}

1;
