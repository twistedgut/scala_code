package XTracker::Stock::Reservation::PreOrderSelectProducts;

use strict;
use warnings;

use XTracker::Logfile                   qw( xt_logger );
use XTracker::Image;
use XTracker::Error;
use XTracker::Utilities                 qw( format_currency_2dp );
use XTracker::Navigation                qw( build_sidenav );
use XTracker::Config::Local             qw(
                                            config_var
                                            get_postcode_required_countries_for_preorder
                                            get_required_address_fields_for_preorder
                                        );

use XTracker::Database::Reservation     qw( :DEFAULT get_reservation_variants );
use XTracker::Database::Product         qw( :DEFAULT get_product_summary );
use XTracker::Database::Utilities       qw( :DEFAULT );
use XTracker::Database::Customer        qw( get_customer_from_pws );
use XTracker::Database::Currency        qw( get_currency_glyph_map get_currencies_from_config );
use XTracker::Database::Stock           qw( :DEFAULT get_saleable_item_quantity get_ordered_item_quantity get_reserved_item_quantity );
use XTracker::Database::Pricing         qw( get_product_selling_price );

use XTracker::Constants::FromDB         qw( :variant_type :reservation_status :pre_order_status :pre_order_item_status :reservation_source );
use XTracker::Constants::Reservations   qw( :reservation_messages :reservation_types );

use Number::Format qw/ round /;
use Template::Stash;
use Try::Tiny;
use List::MoreUtils qw/ uniq /;

my $logger = xt_logger(__PACKAGE__);

sub handler {
    __PACKAGE__->new(XTracker::Handler->new(shift))->process();
}

sub new {
    my ($class, $handler) = @_;

    my $self = {
        handler => $handler
    };

    $handler->{data}{pids_string}   = '';
    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Customer';
    $handler->{data}{subsubsection} = 'Pre Order';
    $handler->{data}{content}       = 'stocktracker/reservation/preorder_selectproducts.tt';
    $handler->{data}{js}            = '/javascript/preorder.js';
    $handler->{data}{css}           = '/css/preorder.css';
    $handler->{data}{sidenav}       = build_sidenav({
        navtype    => 'reservations',
        res_filter => 'Personal'
    });
    $handler->{data}{postcode_countries} = get_postcode_required_countries_for_preorder();
    $handler->{data}{country_areas} = $handler->schema->resultset('Public::CountrySubdivision')
                                                        ->json_country_subdivision_for_ui;

    return bless($self, $class);
}

sub process {
    my ($self) = @_;

    my $handler    = $self->{handler};
    my $customer   = undef;
    my $channel    = undef;
    my $pre_order  = undef;
    my $product    = undef;
    my $rtn_url    = '/StockControl/Reservation/Customer?';
    my @clean_pids = ();
    my @valid_pids = ();

    # Get customer data
    if ($handler->{param_of}{pre_order_id}) {
        $logger->debug('A pre_order_id was provided so lets use that');
        my $err;
        try {
            $handler->{data}{pre_order} = $handler->schema->resultset('Public::PreOrder')->find($handler->{param_of}{pre_order_id});
            $pre_order                  = $handler->{data}{pre_order};
            $err = 0;
        }
        catch {
            $logger->warn($_);
            xt_warn($RESERVATION_MESSAGE__PRE_ORDER_NOT_FOUND);
            $err = 1;
        };
        return $handler->redirect_to('/StockControl/Reservation/Customer') if $err;

        $handler->{data}{sales_channel} = $pre_order->customer->channel->name;
        $handler->{data}{customer}      = $pre_order->customer;
        $customer                       = $pre_order->customer;
        $channel                        = $pre_order->customer->channel;
        $rtn_url                       .= '&pre_order_id='.$pre_order->id;

        unless ($handler->{param_of}{pids}) {
            foreach my $item ($pre_order->pre_order_items->all) {
                push(@clean_pids, {
                    id   => $item->variant->product->id,
                    size => $item->variant->size->id,
                });
            }
        }

        $handler->{data}{reservation_source_id} = $pre_order->reservation_source_id;
        $handler->{data}{reservation_type_id} = $pre_order->reservation_type_id;

    }
    elsif ($handler->{param_of}{customer_id}) {
        $logger->debug('A customer_id was provided so lets use that');
        my $err;
        try {
            $handler->{data}{customer} = $handler->schema->resultset('Public::Customer')->find($handler->{param_of}{customer_id});
            $customer                  = $handler->{data}{customer};
            $err = 0;
        }
        catch {
            $logger->warn($_);
            xt_warn($RESERVATION_MESSAGE__INVALID_CUSTOMER_ID);
            $err = 1;
        };
       return $handler->redirect_to('/StockControl/Reservation/Customer') if $err;

        $handler->{data}{sales_channel} = $handler->{data}{customer}->channel->name;
        $channel                        = $customer->channel;
        $rtn_url                       .= '&customer_id='.$customer->id;

        $handler->{data}{reservation_source_id} = $handler->{param_of}{reservation_source_id};
        $handler->{data}{reservation_type_id} = $handler->{param_of}{reservation_type_id};
    }
    else {
        xt_warn($RESERVATION_MESSAGE__CUSTOMER_NOT_FOUND);
        return $handler->redirect_to('/StockControl/Reservation/Customer');
    }

    if ($handler->{param_of}{pids}) {
        foreach my $dirty_pid (split(/[\n\s,]+/,  $handler->{param_of}{pids})) {
            if ($dirty_pid =~ m/^(\d+)-?(\d+)*/g) {
                if (is_valid_database_id($1)) {
                    push(@clean_pids, {
                        id    => $1,
                        size  => $2,
                    });
                }
                else {
                    xt_warn(sprintf($RESERVATION_MESSAGE__NOT_A_PID_OR_SKU, $1));
                }
            }
        }
    }

    # Check if customer exists on PWS
    unless ($handler->{param_of}{skip_pws_customer_check}) {
        $logger->debug('Calling the PWS for customer check');

        my $err;
        try {
            my $dbh_web = XTracker::Database::get_database_handle({
                name => 'Web_Live_'.$handler->{data}{customer}->channel->business->config_section,
                type => 'readonly',
            });

            my $pws_customer = get_customer_from_pws($dbh_web, $handler->{data}{customer}->is_customer_number);
            $dbh_web->disconnect;
            $err = 0;
            # this needs to be disabled for dev
            unless ($pws_customer) {
                xt_warn($RESERVATION_MESSAGE__CUSTOMER_NOT_ON_PWS);
                $err = 1;
            }
        }
        catch {
            $logger->warn($_);
            xt_warn($RESERVATION_MESSAGE__UNABLE_TO_CONNECT_TO_PWS);
            $err = 1;
        };
        return $handler->redirect_to('/StockControl/Reservation/Customer') if $err;
    }
    else {
        $logger->debug('Skipping the PWS customer check');
    }

    #if user comes from confirmation page
    if($handler->{param_of}{reservation_source_id} ) {
        $handler->{data}{reservation_source_id} = $handler->{param_of}{reservation_source_id};
    }

    if($handler->{param_of}{reservation_type_id} ) {
        $handler->{data}{reservation_type_id} = $handler->{param_of}{reservation_type_id};
    }
    # If these exists then user came back from confirmation page
    if ($handler->{param_of}{variants}) {
        $logger->debug('Variants and reservation source provided so lets repopulate the page');
        if (ref($handler->{param_of}{variants}) eq 'ARRAY') {
            foreach my $variant (@{$handler->{param_of}{variants}}) {
                my ($variant_id, $qty ) = split(/_/, $variant);
                $handler->{data}{checked_variants}{$variant_id}{value} = 1;
                $handler->{data}{checked_variants}{$variant_id}{quantity} = $qty;

            }
        }
        else {
            my ($variant_id, $qty ) = split(/_/, $handler->{param_of}{variants});
            $handler->{data}{checked_variants}{$variant_id}{value} = 1;
            $handler->{data}{checked_variants}{$variant_id}{quantity}  = $qty;
        }
    }

    # Do actions for pre_order only
    $handler->{data}{currencies} = get_currencies_from_config( $handler->schema );

    # Get currency
    if ($handler->{param_of}{currency_id}) {
        $logger->debug('Using selected currency #'.$handler->{param_of}{currency_id});

        my $currency = $handler->schema->resultset('Public::Currency')->find($handler->{param_of}{currency_id});

        $handler->{data}{currency} = {
            id          => $currency->id,
            html_entity => get_currency_glyph_map($handler->{dbh})->{$currency->id}
        }
    }
    else {
        $logger->debug('Using default currency');
        $handler->{data}{currency} = $handler->{data}{currencies}[0];
    }

    # get the Pre-Order Discount information
    my $discount_to_apply = $handler->{param_of}{discount_percentage};
    # the Pre-Order System Config contain Pre-Order Discount settings as well as general Pre-Order settings
    $handler->{data}{discount}                   = $channel->get_pre_order_system_config;
    $handler->{data}{discount}{customer_default} = $customer->get_pre_order_discount_percent;
    $handler->{data}{discount}{to_apply}         = $discount_to_apply * 1
                                            if ( defined $discount_to_apply && $discount_to_apply ne '' );
    # if Discount is 'undef' make it ZERO
    $discount_to_apply //= 0;

    # Get country list - exclusing unkown country from the list
    $handler->{data}{countries} = [$handler->schema->resultset('Public::Country')->search({ code => { '!=' => '' } }, {order_by => 'country'})->all];

    # Get states for United States
    $handler->{data}{country_subdivision} = [$handler->schema->resultset('Public::Country')->find_by_name('United States')->country_subdivisions->all()];

    # Get default shipment address
    my $err;
    try {
        if ($handler->{param_of}{shipment_country_id}) {
            $logger->debug('Using shipment country');
            $handler->{data}{shipment_country} = $handler->schema->resultset('Public::Country')->find($handler->{param_of}{shipment_country_id});
            if ($handler->{param_of}{shipment_country_subdivision_id}) {
                $handler->{data}{shipment_country_subdivision} = $handler->schema->resultset('Public::CountrySubdivision')->find($handler->{param_of}{shipment_country_subdivision_id});
            }
        }
        elsif ($handler->{param_of}{shipment_address_id}) {
            $logger->debug('Using shipment address from database');
            $handler->{data}{shipment_address} = $handler->schema->resultset('Public::OrderAddress')->find($handler->{param_of}{shipment_address_id});
        }
        elsif ($pre_order) {
            $logger->debug('Using shipment address from pre_order');
            $handler->{data}{shipment_address} = $pre_order->shipment_address;
        }
        else {
            $logger->debug('Using shipment address from last order');
            $handler->{data}{shipment_address} = $customer->get_last_shipment_address;
        }

        if($handler->{param_of}{invoice_address_id}) {
            $logger->debug('Using invoice address from database');
            $handler->{data}{invoice_address} = $handler->schema->resultset('Public::OrderAddress')->find($handler->{param_of}{invoice_address_id});
        }
        # Get all shipment addresses
        $handler->{data}{previous_addresses} = $customer->get_all_shipment_addresses_valid_for_preorder;
        $err = 0;
    }
    catch {
        $logger->warn($_);
        $logger->debug('No shipment address for this customer');
        $handler->{data}{shipment_address}   = undef;
        $handler->{data}{previous_addresses} = [];
        xt_warn('Unable to continue. Cant find address');
        $err = 1;
    };
    return $handler->process_template if $err;

    # If the shipping address is not valid for a Pre-Order, don't use it.
    if ( $handler->{data}{shipment_address} && !$handler->{data}{shipment_address}->is_valid_for_pre_order ) {
        $handler->{data}{shipment_address} = undef;
    }

    unless ($handler->{data}{shipment_address} || $handler->{data}{shipment_country}) {
        xt_warn('No shipping address for this customer');
        return $handler->process_template;
    }

    # Loop through each PID submited
    foreach my $clean_product (@clean_pids) {
        my $skip_next;
        try {
            $product = $handler->{schema}->resultset('Public::Product')->find($clean_product->{id});
            $skip_next = 0;
        }
        catch {
            $logger->warn($_);
            xt_warn(sprintf($RESERVATION_MESSAGE__CANT_FIND_PRODUCT, $clean_product->{id}));
            $skip_next = 1;
        };
        next if $skip_next;

        # Skip if product not found
        unless ($product) {
            xt_warn(sprintf($RESERVATION_MESSAGE__CANT_FIND_PRODUCT, $clean_product->{id}));
            next;
        }

        # Skip if product not in this channel
        unless ($product->get_product_channel->channel_id == $channel->id) {
            xt_warn(sprintf($RESERVATION_MESSAGE__PRODUCT_WRONG_CHANNEL, $product->id));
            next;
        }

        $logger->debug('Fetching data for product #'.$product->id);

        try {
            # Get images for products
            $handler->{data}{products}{$product->id}{images} = get_images({
                product_id     => $product->id,
                live           => 1,
                schema         => $handler->{schema},
                business_id    => $channel->business_id,
                image_host_url => $handler->{data}{image_host_url},
            });

            my @variants  = $product->get_variants_with_defined_sizes();

            # Get product description
            $handler->{data}{products}{$product->id}{data} = {
                description => $product->preorder_name,
            };

            $handler->{data}{products}{$product->id}{can_be_pre_ordered}
                = $product->can_be_pre_ordered_in_channel($channel->id);

            if ($handler->{data}{shipment_address}) {
                $handler->{data}{products}{$product->id}{can_ship} = $product->can_ship_to_address(
                    $handler->{data}{shipment_address},
                    $channel
                );
            }
            else {
                $handler->{data}{products}{$product->id}{can_ship} = $product->can_ship_to_location(
                    country => $handler->{data}{shipment_country},
                    county  => ($handler->{data}{shipment_country_subdivision} ? $handler->{data}{shipment_country_subdivision}->iso : ''),
                    channel => $channel,
                );
            }

            unless ($handler->{data}{products}{$product->id}{can_ship}) {
                $logger->debug('Product cant be shipped');
                return; # returns from the try, into the for
            }

            unless ($handler->{data}{products}{$product->id}{can_be_pre_ordered}) {
                $logger->debug('Product cant be pre ordered');
                return; # returns from the try, into the for
            }

            $logger->debug('Fetching selling price for product #'.$product->id);

            # Get price, tax and duty for product
            $handler->{data}{products}{ $product->id }{price} = $self->_get_formatted_product_selling_price(
                $customer,
                $product,
            );

            if ( $discount_to_apply ) {
                # because of the smaller unit price after a discount might effect the
                # tax & duty rates, applying the discount is not just a case of taking
                # X% off the above original price, so need to get the prices again
                $handler->{data}{products}{ $product->id }{discount_price} = $self->_get_formatted_product_selling_price(
                    $customer,
                    $product,
                    $discount_to_apply,
                );
            }

            foreach my $variant (@variants) {
                $logger->debug('Fetching data for variant #'.$variant->id);

                my $variant_pre_order_by_customer = 0;
                my $variant_pre_orders_count      = 0;

                my @all_variant_pre_orders = $handler->{schema}->resultset('Public::PreOrderItem')->search({
                    variant_id               => $variant->id,
                    pre_order_item_status_id => { 'IN' => [
                                                            $PRE_ORDER_ITEM_STATUS__CONFIRMED,
                                                            $PRE_ORDER_ITEM_STATUS__COMPLETE,
                                                            $PRE_ORDER_ITEM_STATUS__EXPORTED
                                                    ] },
                });

                if (@all_variant_pre_orders) {
                    $variant_pre_orders_count = @all_variant_pre_orders;
                    foreach my $variant_pre_order (@all_variant_pre_orders) {
                        $variant_pre_order_by_customer++ if ($variant_pre_order->pre_order->customer_id == $customer->id);
                    }
                }

                # Build variant data structure
                $handler->{data}{products}{$product->id}{variants}{$variant->id} = {
                    sku                  => $variant->sku,
                    designer_size        => $variant->designer_size->size,
                    freestock            => $variant->current_stock_on_channel($channel->id) || 0,
                    on_order             => $variant->get_ordered_quantity_for_channel($channel->id) || 0,
                    reserved_qty         => $variant->get_reservation_count_for_status($RESERVATION_STATUS__PENDING) || 0,
                    total_pre_orders     => $variant_pre_orders_count,
                    customer_pre_orders  => $variant_pre_order_by_customer,
                    can_be_pre_ordered   => $variant->can_be_pre_ordered_in_channel($channel->id),
                    available_quantity   => $variant->get_stock_available_for_pre_order_for_channel($channel->id) || 0,
                };
            }

            push(@valid_pids, $clean_product->{id});
        }
        catch {
            $logger->warn($_);
            delete($handler->{data}{products}{$clean_product->{id}});
            xt_warn(sprintf($RESERVATION_MESSAGE__CANT_FIND_PRODUCT_DATA, $clean_product->{id}));
        };
    }

    # Get reservation sources
    $handler->{data}{reservation_source_list}
        = [$handler->schema->resultset('Public::ReservationSource')->active_list_by_sort_order->all];

    # Get reservation types
    $handler->{data}{reservation_type_list}
        = [$handler->schema->resultset('Public::ReservationType')->list_by_sort_order->all];


    $handler->{data}{pids}   = join("\n", uniq(@valid_pids));
    $handler->{data}{params} = $handler->{param_of};

    return $handler->process_template;
}

sub _get_formatted_product_selling_price {
    my ( $self, $customer, $product, $discount_to_apply ) = @_;

    $discount_to_apply //= 0;
    my $handler = $self->{handler};

    # Get price for product
    my ( $unit_price, undef, undef ) = get_product_selling_price($handler->dbh, {
        customer_id       => $customer->id,
        product_id        => $product->id,
        county            => ($handler->{data}{shipment_address} ? $handler->{data}{shipment_address}->county : ($handler->{data}{shipment_country_subdivision} ? $handler->{data}{shipment_country_subdivision}->iso : '')),
        country           => ($handler->{data}{shipment_address} ? $handler->{data}{shipment_address}->country : $handler->{data}{shipment_country}->country),
        order_currency_id => $handler->{data}{currency}{id},
        order_total       => 0,
        pre_order_discount => $discount_to_apply,
    });

    # Get tax and duty for product
    my ( undef, $tax, $duty ) = get_product_selling_price($handler->dbh, {
        customer_id       => $customer->id,
        product_id        => $product->id,
        county            => ($handler->{data}{shipment_address} ? $handler->{data}{shipment_address}->county : ($handler->{data}{shipment_country_subdivision} ? $handler->{data}{shipment_country_subdivision}->iso : '')),
        country           => ($handler->{data}{shipment_address} ? $handler->{data}{shipment_address}->country : $handler->{data}{shipment_country}->country),
        order_currency_id => $handler->{data}{currency}{id},
        order_total       => $unit_price,
        pre_order_discount => $discount_to_apply,
    });

    return {
        unit_price => format_currency_2dp( $unit_price ),
              duty => format_currency_2dp( $duty ),
               tax => format_currency_2dp( $tax ),
             total => format_currency_2dp( round($unit_price, 2) + round($duty, 2) + round($tax, 2) ),
    };
}

1;
