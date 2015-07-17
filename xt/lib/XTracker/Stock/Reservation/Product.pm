package XTracker::Stock::Reservation::Product;

use strict;
use warnings;

use DateTime;

use XTracker::Error;
use XTracker::Handler;
use XTracker::Navigation;

use XTracker::Database::Reservation qw( :DEFAULT get_reservation_products get_reservation_variants list_product_reservations can_reserve );
use XTracker::Database::Product qw( :DEFAULT get_product_summary );
use XTracker::Database::Stock qw( :DEFAULT get_saleable_item_quantity get_ordered_item_quantity get_reserved_item_quantity );
use XTracker::Database::Attributes qw( get_designer_atts
                                       get_season_atts
                                       get_product_type_atts );
use XTracker::Database::Channel qw( get_channels );
use XTracker::Database::Variant qw( :validation );
use XTracker::Database::Utilities qw( is_valid_database_id );

use XTracker::Image;

use XTracker::Constants::FromDB qw( :reservation_status );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $dt                  = DateTime->now( time_zone => "local" );
    $handler->{data}{year}  = $dt->year;

    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Product';
    $handler->{data}{subsubsection} = 'Search';
    $handler->{data}{content}       = 'stocktracker/reservation/product.tt';
    $handler->{data}{css}           = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}            = [
        '/yui/yahoo-dom-event/yahoo-dom-event.js',
        '/yui/element/element-min.js',
        '/yui/tabview/tabview-min.js',
        '/javascript/json2.js'
     ];


    $handler->{data}{RESERVATION_STATUS__CANCELLED} = $RESERVATION_STATUS__CANCELLED;
    $handler->{data}{RESERVATION_STATUS__PURCHASED} = $RESERVATION_STATUS__PURCHASED;
    $handler->{data}{RESERVATION_STATUS__PENDING}   = $RESERVATION_STATUS__PENDING;
    # build side nav
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'reservations', res_filter => 'Personal' } );

    # search field lists
    $handler->{data}{designers} = get_designer_atts( $handler->{dbh} );
    $handler->{data}{seasons}   = get_season_atts( $handler->{dbh} );
    $handler->{data}{types}     = get_product_type_atts( $handler->{dbh} );

    my $channels    = get_channels( $handler->{dbh} );
    my $invalid_params = {};

    # search form submitted
    if ( $handler->{param_of}{'search'} ) {

        if ( $handler->{param_of}{'sku'} ) {
            if ( !is_valid_sku($handler->{param_of}{'sku'} )) {
                $invalid_params->{'SKU'}++;
            } else {
                my $var_id = get_variant_by_sku( $handler->{dbh}, $handler->{param_of}{'sku'} );
                $handler->{param_of}{'product_id'} = get_product_id( $handler->{dbh}, { 'type' => 'variant_id', 'id' => $var_id } );
            }
        }

        if ( $handler->{param_of}{'designer'} || $handler->{param_of}{'season'} || $handler->{param_of}{'type'} ){
            $handler->{data}{products} = get_reservation_products($handler->{dbh}, $handler->{param_of}{'designer'}, $handler->{param_of}{'season'}, $handler->{param_of}{'type'} );

            # get images
            foreach my $id ( keys %{ $handler->{data}{products} } ) {
                $handler->{data}{products}{$id}{image} = get_images({
                    product_id => $id,
                    live => $handler->{data}{products}{$id}{live},
                    schema => $handler->schema,
                    business_id => $channels->{ $handler->{data}{products}{$id}{channel_id} }{business_id},
                    image_host_url => $handler->{data}{image_host_url}
                });
            }
        }
    }

    # get product data if we have a product id
    if ( $handler->{param_of}{'product_id'} ) {

        if ( !is_valid_database_id($handler->{param_of}{'product_id'}) ) {
            $invalid_params->{'Product ID'}++;
        } else {
            $handler->{data}{product_id}    = $handler->{param_of}{'product_id'};

            $handler->add_to_data( get_product_summary( $handler->schema, $handler->{data}{product_id} ) );

            # Reservation Sources
            $handler->{data}{reservation_source_list}   = [ $handler->schema->resultset('Public::ReservationSource')->active_list_by_sort_order->all ];
            $handler->{data}{reservation_type_list}     = [ $handler->schema->resultset('Public::ReservationType')->list_by_sort_order->all ];

            # can this user reserve this product?
            $handler->{data}{can_reserve} = can_reserve( $handler->{dbh}, $handler->{data}{department_id}, $handler->{data}{product_id} );

            my $sales_channel = $handler->{data}{active_channel}{channel_name};
            $handler->{data}{sales_channel} = $handler->{data}{active_channel}{channel_name};

            # pre-order is active?
            $handler->{data}{channel}      = $handler->schema->resultset('Public::Channel')->find( $handler->{data}{active_channel}{channel_id} );
            $handler->{data}{is_pre_order_active} = $handler->{data}{channel}->is_pre_order_active();

            # list of variants on product
            $handler->{data}{variants}  = get_reservation_variants($handler->{dbh}, $handler->{data}{product_id});



            # free stock, ordered and reserved qty info for product
            $handler->{data}{free_stock}    = get_saleable_item_quantity($handler->{dbh}, $handler->{data}{product_id});
            $handler->{data}{ordered}       = get_ordered_item_quantity($handler->{dbh}, $handler->{data}{product_id});
            $handler->{data}{reserved_qty}  = get_reserved_item_quantity($handler->{dbh}, $handler->{data}{product_id}, $RESERVATION_STATUS__UPLOADED);

            # get stock info for each variant for each sales channel
            foreach my $channel ( keys %{ $handler->{data}{variants} } ) {
                foreach my $var_id ( keys %{ $handler->{data}{variants}{ $channel } } ) {
                    $handler->{data}{variants}{ $channel }{$var_id}{ordered}        = $handler->{data}{ordered}{ $channel }{ $var_id } || 0;
                    $handler->{data}{variants}{ $channel }{$var_id}{onhand}         = $handler->{data}{free_stock}{ $channel }{ $var_id } || 0;
                    $handler->{data}{variants}{ $channel }{$var_id}{reservation}    = $handler->{data}{reserved_qty}{ $channel }{ $var_id } || 0;
                    $handler->{data}{variants}{ $channel }{$var_id}{is_preorder}    = 0;
                    if ( $handler->{data}{variants}{ $channel }{$var_id}{preorder_count} > 0 ) {
                        $handler->{data}{variants}{ $channel }{$var_id}{is_preorder} = 1;
                    }
                }
            }

            $handler->{data}{reservations} = list_product_reservations($handler->{dbh}, $handler->{data}{product_id});

            # Get list of operators for 'Change Operator' in 'Edit Special Order'.
            $handler->{data}{operators_new} = [
                $handler->schema->resultset('Public::Operator')
                    ->by_authorisation( 'Stock Control' => 'Reservation' )
                    ->search( undef, { order_by => 'name' } )
                    ->all
            ];

            # format list into hash for page
            foreach my $channel ( keys %{ $handler->{data}{reservations} } ) {
                foreach my $id ( keys %{ $handler->{data}{reservations}{$channel} } ) {

                    my $variant_id  = $handler->{data}{reservations}{ $channel }{$id}{variant_id};
                    my $ordering_id = $handler->{data}{reservations}{ $channel }{$id}{ordering_id};

                    # defining new key to separate out pre-order data from normal reservations
                    my $handler_data;
                    if( $handler->{data}{reservations}{ $channel }{$id}{preorder} ) {
                        $handler_data = $handler->{data}{reservationlist}{ $channel }{ $variant_id }{preorder_data} //= {};
                        # Ordering concept does not exist for pre-orderjust creating data hash on reservation id
                        $ordering_id= $handler->{data}{reservations}{ $channel }{$id}{id};
                    } else  {
                        $handler_data = $handler->{data}{reservationlist}{ $channel }{ $variant_id }{reservation_data} //= {};
                    }

                    $handler_data->{ $ordering_id } = $handler->{data}{reservations}{ $channel }{$id};

                    # data for pre order
                    $handler_data->{ $ordering_id}{preorder} = $handler->{data}{reservations}{ $channel }{$id}{preorder};

                    if( $handler->{data}{reservations}{ $channel }{$id}{preorder}) {
                        my $pre_order_item = $handler->schema->resultset('Public::PreOrderItem')->find( $handler->{data}{reservations}{ $channel }{$id}{preorder} );
                        $handler_data->{ $ordering_id }{pre_order_item_obj} = $pre_order_item;
                        $handler_data->{ $ordering_id }{pre_order_created} = $pre_order_item->pre_order->created;
                        $handler->{data}{show_preorder_headers}{ $channel }{ $variant_id }  = 1;

                        # CANDO-977
                        my $variant_obj = $pre_order_item->variant;
                        $handler->{data}{variants}{ $channel }{$variant_id}{shipping_window} = $variant_obj->get_estimated_shipping_window();
                    } else {
                        $handler->{data}{show_reservation_headers}{ $channel }{ $variant_id }  = 1;
                    }

                    $handler_data->{ $ordering_id }{reservation_id}    = $id;
                    $handler_data->{ $ordering_id }{customer_name}     = $handler->{data}{reservations}{ $channel }{$id}{first_name}." ".$handler->{data}{reservations}{ $channel }{$id}{last_name};
                    $handler_data->{ $ordering_id }{customer_class_id} = $handler->{data}{reservations}{ $channel }{$id}{customer_class_id};
                    $handler_data->{ $ordering_id }{customer_category} = $handler->{data}{reservations}{ $channel }{$id}{customer_category};

                    # Determine if the operator can update the operator who owns the reservation.
                    my $reservation = $handler->schema->resultset('Public::Reservation')->find($id);
                    # TODO: Now the "can_update_operator" method returns information about why a
                    # reservation cannot be update, this could be used in the page.
                    ( $handler_data->{ $ordering_id }{can_update_operator} )
                        = $reservation->can_update_operator( $handler->{data}{operator_id} );

                    # Get reservation's department id
                    $handler_data->{ $ordering_id }->{ department_id } = $handler->{data}{ reservations }{ $channel }{ $id }{ department_id };

                    # Get a count of log entries.
                    $handler_data->{ $ordering_id }{operator_history_count} = $reservation->reservation_operator_logs->count;
                }
            }
        }
    }

    # Only show validation errors if nothing was returned
    unless ($handler->{data}{reservations}) {
        foreach my $invalid_param ( sort keys( %{$invalid_params} ) ) {
            my $key = $invalid_param =~ y/A-Z /a-z_/r;
            xt_warn("$invalid_param \"$handler->{param_of}{$key}\" is invalid");
        }
    }

    return $handler->process_template;
}

1;
