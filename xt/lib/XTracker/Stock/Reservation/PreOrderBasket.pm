package XTracker::Stock::Reservation::PreOrderBasket;

use strict;
use warnings;

use XTracker::Logfile                   qw( xt_logger );
use XTracker::Navigation                qw( build_sidenav );
use XTracker::Image;
use XTracker::Error;
use XTracker::Utilities                 qw( format_currency_2dp :string );
use XTracker::Config::Local             qw( config_var has_delivery_signature_optout get_postcode_required_countries_for_preorder);

use XTracker::Database::Reservation     qw( :DEFAULT get_reservation_variants );
use XTracker::Database::Product         qw( :DEFAULT );
use XTracker::Database::Utilities       qw( :DEFAULT );
use XTracker::Database::Customer        qw( get_customer_from_pws );
use XTracker::Database::Currency        qw( get_currency_glyph_map get_currencies_from_config );
use XTracker::Database::Stock           qw( :DEFAULT get_saleable_item_quantity get_ordered_item_quantity get_reserved_item_quantity );
use XTracker::Database::Pricing         qw( get_product_selling_price );
use XTracker::Database::Shipment        qw( get_address_shipping_charges );

use XTracker::Constants::FromDB         qw( :variant_type :reservation_status :pre_order_status :pre_order_item_status :reservation_source );
use XTracker::Constants::Reservations   qw( :reservation_messages :reservation_types :pre_order_packaging_types );
use XTracker::Constants::Payment        qw( :payment_card_types );

use XTracker::Vertex                    qw( :pre_order );

use Number::Format                      qw( :subs );
use URI::Escape;
use Try::Tiny;

my $logger = xt_logger(__PACKAGE__);

sub handler {
    __PACKAGE__->new(XTracker::Handler->new(shift))->process();
}

sub new {
    my ($class, $handler, $config) = @_;

    my $self = {
        handler => $handler
    };

    $handler->{data}{section}            = 'Reservation';
    $handler->{data}{subsection}         = 'Customer';
    $handler->{data}{subsubsection}      = 'Pre Order Basket';
    $handler->{data}{content}            = 'stocktracker/reservation/pre_order_basket.tt';
    $handler->{data}{js}                 = '/javascript/preorder.js';
    $handler->{data}{css}                = '/css/preorder.css';
    $handler->{data}{sidenav}            = build_sidenav({
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
    my $schema     = $handler->schema;
    my $customer   = undef;
    my $channel    = undef;
    my $pre_order  = undef;
    my @variants   = ();
    my $variant_quantity ;
    my $rtn_url    = 'SelectProducts?pids='.( $handler->{data}{param_of}{pids} ? uri_escape($handler->{data}{param_of}{pids}) : '' );

    # Get customer data
    if ($handler->{param_of}{pre_order_id}) {
        $logger->debug('A pre_order_id was provided so lets use that');
        my $err;
        try {
            $handler->{data}{pre_order} = $schema->resultset('Public::PreOrder')->find($handler->{param_of}{pre_order_id});
            $pre_order                  = $handler->{data}{pre_order};
            $err = 0;
        }
        catch {
            $err = 1;
            $logger->warn($_);
            xt_warn($RESERVATION_MESSAGE__PRE_ORDER_NOT_FOUND);
        };
        return $handler->redirect_to('/StockControl/Reservation/Customer') if $err;

        $handler->{data}{sales_channel} = $pre_order->customer->channel->name;
        $handler->{data}{customer}      = $pre_order->customer;
        $customer                       = $pre_order->customer;
        $channel                        = $pre_order->customer->channel;
        $rtn_url                       .= '&pre_order_id='.$pre_order->id;

        # if there is a payment for this Pre-Order then we can't Edit this any
        # longer because it will delete and re-insert Pre-Order Item rows and
        # then loose the relationship with the Reservations that it has created
        # and so should be sent to the Payment page to Complete the Payment
        if ( $handler->{data}{pre_order}->get_payment() ) {
            xt_warn( sprintf( $RESERVATION_MESSAGE__ALREADY_GOT_PAYMENT_RECORD, $handler->{data}{pre_order}->pre_order_number ) );
            return $handler->redirect_to( '/StockControl/Reservation/PreOrder/Payment?pre_order_id=' . $handler->{data}{pre_order}->id );
        }
    }
    elsif ($handler->{param_of}{customer_id}) {
        $logger->debug('A customer_id was provided so lets use that');
        my $err;
        try {
            $handler->{data}{customer} = $schema->resultset('Public::Customer')->find($handler->{param_of}{customer_id});
            $customer                  = $handler->{data}{customer};
            $err = 0;
        }
        catch {
            $err = 1;
            $logger->warn($_);
            xt_warn($RESERVATION_MESSAGE__INVALID_CUSTOMER_ID);
        };
        return $handler->redirect_to('/StockControl/Reservation/Customer') if $err;

        $handler->{data}{sales_channel} = $handler->{data}{customer}->channel->name;
        $channel                        = $customer->channel;
        $rtn_url                       .= '&customer_id='.$customer->id;

        unless ($handler->{param_of}{reservation_source_id}) {
            xt_warn($RESERVATION_MESSAGE__NO_RSV_SRC_SELECTED);
            return $handler->redirect_to($rtn_url);
        }
        unless ($handler->{param_of}{reservation_type_id}) {
            xt_warn($RESERVATION_MESSAGE__NO_RSV_TYPE_SELECTED);
            return $handler->redirect_to($rtn_url);
        }
    }
    else {
        xt_warn($RESERVATION_MESSAGE__CUSTOMER_NOT_FOUND);
        return $handler->redirect_to('/StockControl/Reservation/Customer');
    }


    if ($handler->{param_of}{variants}) {
        my @ids;

        if (ref($handler->{param_of}{variants}) eq 'ARRAY') {
            @ids = @{$handler->{param_of}{variants}};
        }
        else {
            push(@ids, $handler->{param_of}{variants});
        }

        my @return_variants;
        foreach my $variant_id (@ids) {
            next if $variant_id eq '0';
            my $quantity;
            ($variant_id,$quantity) =  split(/_/, $variant_id);
            $variant_quantity->{$variant_id} = $quantity // 1;

            try {
                my $variant = $schema->resultset('Public::Variant')->find($variant_id);
                push(@variants, $variant);
                push(@return_variants, $variant_id."_".$quantity);
            }
            catch {
                xt_warn(sprintf($RESERVATION_MESSAGE__CANT_FIND_VARIANT, $variant_id));
                $logger->warn($_);
            };
        }

        $rtn_url .= '&variants='.join('&variants=', @return_variants);
    }
    elsif ($pre_order) {
        foreach my $item ($pre_order->pre_order_items) {
            push(@variants, $item->variant);
        }
    }
    else {
        xt_warn($RESERVATION_MESSAGE__NO_PRODUCTS_SELECTED);
        return $handler->redirect_to($rtn_url);
    }

    # check all Variants can still be Pre-Ordered
    my @skus_not_allowed = map { $_->sku } grep {
        !$_->can_be_pre_ordered_in_channel( $channel->id )
    } @variants;
    if ( @skus_not_allowed ) {
        # add the Variants to the redirect URL if they haven't already been
        my $variant_params = '';
        if ( $rtn_url !~ m/variants=\d/ ) {
            $variant_quantity //= {};
            $variant_params = '&variants=' . join(
                '&variants=',
                map { $_->id . '_' . ( $variant_quantity->{ $_->id } // 1 ) } @variants
            );
        }
        my $message = sprintf( $RESERVATION_MESSAGE__UNABLE_TO_PRE_ORDER_SKUS, join( ', ', @skus_not_allowed ) );
        $logger->warn( $message );
        xt_warn( $message );
        return $handler->redirect_to( $rtn_url . $variant_params );
    }

    my $country_rs = $schema->resultset('Public::Country');

    # Get country list - excluding unknown country from the list
    $handler->{data}{countries} = [$country_rs->search({ code => { '!=' => '' } }, {order_by => 'country'})->all];

    # Get states for United States
    $handler->{data}{country_subdivision} = [$country_rs->find_by_name('United States')->country_subdivisions->all()];

    # Get currencies
    $handler->{data}{currencies} = get_currencies_from_config( $schema );

    my $selected_currency_id = strip( $handler->{param_of}{currency_id} )
                                    || ( $pre_order ? $pre_order->currency_id : undef );
    my $default_currency     = shift( @{get_currencies_from_config( $schema )} );

    # Currency
    if ( $handler->{data}{read_only} ) {
        $logger->debug('Using existing pre-order currency');

        my $currency_id = $pre_order->currency_id;

        $handler->{data}{currency} = {
            id          => $currency_id,
            html_entity => get_currency_glyph_map($handler->{dbh})->{$currency_id}
        }
    }
    elsif ( $selected_currency_id ) {
        $logger->debug('Using selected currency #'.$selected_currency_id);

        try {
            my $currency = $schema->resultset('Public::Currency')->find( $selected_currency_id );

            my $currency_id = $currency ? $selected_currency_id
                                        : $default_currency->id;

            $handler->{data}{currency} = {
                id          => $currency_id,
                html_entity => get_currency_glyph_map($handler->{dbh})->{$currency_id}
            }
        }
        catch {
            $logger->warn($_);
            $logger->debug('Something went wronng. Using default curerncy');
            $handler->{data}{currency} = $default_currency;
        };
    }
    else {
        $logger->debug('Using default currency');
        $handler->{data}{currency} = $default_currency;
    }
    # set 'param_of' to make sure the Currency Option gets 'selected'
    $handler->{param_of}{currency_id} = $handler->{data}{currency}{id};

    my ( $shipment_address_id, $invoice_address_id ) = strip(
        @{$handler->{param_of}}{qw( shipment_address_id invoice_address_id ) }
    );

    my $order_address_rs = $schema->resultset('Public::OrderAddress');

    # Shipment Address
    if ($shipment_address_id) {
        $logger->debug('Shipment address id provided');
        $handler->{data}{shipment_address} = $order_address_rs->find($shipment_address_id);
    }
    elsif ($pre_order) {
        $handler->{data}{shipment_address} = $order_address_rs->find($pre_order->shipment_address_id);
    }
    else {
        $logger->debug('Using shipment address from last order');
        $handler->{data}{shipment_address} = $customer->get_last_shipment_address();
    }

    # Invoice Address
    if ($invoice_address_id) {
        $logger->debug('Invoice address id provided');
        $handler->{data}{invoice_address} = $order_address_rs->find($invoice_address_id);
    }
    elsif ($pre_order) {
        $handler->{data}{invoice_address} = $order_address_rs->find($pre_order->invoice_address_id);
    }
    else {
        $logger->debug('Using invoice address from last order');
        $handler->{data}{invoice_address} = $customer->get_last_invoice_address();
    }

    # Get all addresses
    $handler->{data}{previous_addresses} = $customer->get_all_used_addresses_valid_for_preorder;

    # Get default packaging type
    $handler->{data}{packaging_type} = $schema->resultset('Public::PackagingType')->find_by_name($RESERVATION_PRE_ORDER__DEFAULT_PACKAGING_TYPE);

    # Get signature flag
    $handler->{data}{has_delivery_signature_optout} = has_delivery_signature_optout();

    # get the Discount (if any) to Apply and also populate the 'data' hash ref. so
    # this can be picked up in the TT document, the Pre-Order System Config entries
    # contain Pre-Order Discount settings as well as general Pre-Order settings
    $handler->{data}{discount}                   = $channel->get_pre_order_system_config;
    $handler->{data}{discount}{customer_default} = $customer->get_pre_order_discount_percent;

    my $discount_percentage;
    my $discount_operator_id;
    if ( $handler->{data}{discount}{can_apply_discount} ) {
        # if 'discount_to_apply' is an empty string then make it 'undef'
        my $param_discount = $handler->{param_of}{discount_to_apply};
        $param_discount    = undef      if ( defined $param_discount && $param_discount eq '' );
        if ( defined $param_discount || ( $pre_order && $pre_order->applied_discount_operator_id ) ) {
            $discount_percentage  = $param_discount // ( $pre_order ? $pre_order->applied_discount_percent : undef );
            # set the Operator Id to be current user if any kind of Discount is being applied
            $discount_operator_id = $handler->{data}{operator_id};
            # this will set the 'selected' discount in the TT document
            $handler->{data}{discount}{to_apply} = $discount_percentage * 1;
        }
    }

    # Pre Order Database
    my $just_created_new_pre_order  = 0;
    if ($pre_order) {
        $logger->debug('Updating existing pre_order');

        my $update_args = {
            operator_id           => $handler->{data}{operator_id},
            pre_order_status_id   => $PRE_ORDER_STATUS__INCOMPLETE,
            shipment_address_id   => $handler->{data}{shipment_address}->id,
            invoice_address_id    => $handler->{data}{invoice_address}->id,
            currency_id           => $handler->{data}{currency}{id},
            total_value           => 0,
            # if 'telephone' fields haven't been passed then we
            # must have come from the Select Items page and so should
            # use the current contents of the telephone fields on
            # the Pre Order record itself
            telephone_day         => $handler->{param_of}{telephone_day} // $pre_order->telephone_day,
            telephone_eve         => $handler->{param_of}{telephone_eve} // $pre_order->telephone_eve,
            signature_required    => strip( $handler->{param_of}{signature_required} ) // 1,
            applied_discount_percent     => $discount_percentage // 0,
            applied_discount_operator_id => $discount_operator_id,
        };

        # get the Shipping Option from the params passed in or use existing
        my $shipping_charge_id = strip( $handler->{param_of}{shipment_option_id} )
                                        || $pre_order->shipping_charge_id;

        if ( $shipping_charge_id ) {
            $update_args->{shipping_charge_id} = $shipping_charge_id;
            # set 'param_of' to make sure the Shipping Option gets 'selected'
            $handler->{param_of}{shipment_option_id} = $shipping_charge_id;
        }
        my $err;
        try {
            # wrap in a transaction to avoid a failed update from
            # trashing what we already have

            $schema->txn_do( sub {
                $pre_order->update( $update_args );
                $pre_order->pre_order_items->search_related('pre_order_item_status_logs')->delete;
                $pre_order->pre_order_items->delete;
            } );
            $err = 0;
        }
        catch {
            $err = 1;
            # this is pretty severe, and we should find a way to preserve what
            # the user has entered, and allow them to fix it
            $logger->warn($_);
            xt_die($RESERVATION_MESSAGE__CANT_UPDATE_PRE_ORDER);
        };
        return $handler->redirect_to('/StockControl/Reservation/Customer?customer_id='.$customer->id) if $err
    }
    else {
        $logger->debug('Creating new pre_order');
        my $err;
        try {
            my $recent_order    = $customer->get_most_recent_order;

            my $reservation_source_id = trim( $handler->{param_of}{reservation_source_id} );
            my $reservation_type_id   = trim( $handler->{param_of}{reservation_type_id} );

            $handler->{data}{pre_order} = $schema->resultset('Public::PreOrder')->create({
                customer_id           => $customer->id,
                operator_id           => $handler->{data}{operator_id},
                pre_order_status_id   => $PRE_ORDER_STATUS__INCOMPLETE,
                shipment_address_id   => $handler->{data}{shipment_address}->id,
                invoice_address_id    => $handler->{data}{invoice_address}->id,
                reservation_source_id => $reservation_source_id,
                reservation_type_id   => $reservation_type_id,
                currency_id           => $handler->{data}{currency}{id},
                packaging_type_id     => $handler->{data}{packaging_type}->id,
                total_value           => 0,
                telephone_day         => ($recent_order ? $recent_order->telephone : ''),
                telephone_eve         => ($recent_order ? $recent_order->mobile_telephone : ''),
                applied_discount_percent     => $discount_percentage // 0,
                applied_discount_operator_id => $discount_operator_id,
            });
            # log when this whole thing started
            $handler->{data}{pre_order}->discard_changes
                                       ->update_status( $PRE_ORDER_STATUS__INCOMPLETE, $handler->{data}{operator_id} );
            $logger->debug('New database record created #'.$handler->{data}{pre_order}->id);
            $just_created_new_pre_order = 1;
            $err = 0;
        }
        catch {
            $err = 1;
            $logger->warn($_);
            xt_die($RESERVATION_MESSAGE__CANT_CREATE_PRE_ORDER);
        };
        return $handler->redirect_to('/StockControl/Reservation/Customer?customer_id='.$customer->id) if $err;

        $pre_order = $handler->{data}{pre_order};
    }

    my $dc = config_var('DistributionCentre', 'name');

  VARIANT:
    foreach my $variant (@variants) {
        $logger->debug('Looking for variant #'.$variant->id);

        $handler->{data}{variants}{$variant->id}{images} = get_images({
            product_id     => $variant->product_id,
            live           => 1,
            schema         => $schema,
            business_id    => $channel->business_id,
            image_host_url => $handler->{data}{image_host_url}
        });

        $handler->{data}{variants}{$variant->id}{data} = {
            variant_id    => $variant->id,
            sku           => $variant->sku,
            id            => $variant->id,
            size          => $variant->size->size,
            designer_size => $variant->designer_size->size,
            designer      => $variant->product->designer->designer,
            name          => $variant->product->preorder_name,
        };

        $handler->{data}{variants}{$variant->id}{sort_key} = $variant->sku;

        # quit processing this item if we can't ship it
        unless ($variant->product->can_ship_to_address($handler->{data}{shipment_address},$channel)) {
            $logger->debug('Variant #'.$variant->product->id.' has shipment restrictions to '.$handler->{data}{shipment_address}->country);
            $handler->{data}{variants}{$variant->id}{can_ship} = 0;

            next VARIANT;
        }

        $logger->debug('Variant #'.$variant->product->id.' has no shipment restrictions to '.$handler->{data}{shipment_address}->country);

        $handler->{data}{variants}{$variant->id}{can_ship} = 1;

        # Get price (with any Discount) for product & tax and duty
        # Note that tax information may get blitzed by Vertex in a minute...
        my $price = $self->_get_product_selling_price_tax_duty(
            $customer,
            $variant->product,
            $pre_order->applied_discount_percent
        );
        # get the non-discounted price (could be the same as above, if discount is zero)
        my $original_price = $self->_get_product_selling_price_tax_duty(
            $customer,
            $variant->product,
        );

        # Update pre_order_item table
        try {
                my $pre_order_qty = $variant_quantity->{$variant->id} // 1;
                foreach( 1..$pre_order_qty ) {
                    $logger->debug('Creating database entry in PreOrderItem');
                    $schema->resultset('Public::PreOrderItem')->create({
                        pre_order_id             => $pre_order->id,
                        variant_id               => $variant->id,
                        pre_order_item_status_id => $PRE_ORDER_ITEM_STATUS__SELECTED,
                        # Round to two decimal places
                        tax                      => round( $price->{tax} ),
                        duty                     => round( $price->{duty} ),
                        unit_price               => round( $price->{unit_price} ),
                        original_tax             => round( $original_price->{tax} ),
                        original_duty            => round( $original_price->{duty} ),
                        original_unit_price      => round( $original_price->{unit_price} ),
                    });
                }
        }
        catch {
            $logger->warn($_);
            xt_die($RESERVATION_MESSAGE__CANT_CREATE_PRE_ORDER_ITEM);
        };
    }

    # Get shipping options
    try {
        my $exclude_nominated_day = 0;
        my $always_keep_sku       = '';
        my $customer_facing_only  = 1;

        $logger->debug('Getting shipment options');
        my %shipment_options    = get_address_shipping_charges(
            $handler->{dbh},
            $channel->id,
            {
                country  => $handler->{data}{shipment_address}->country,
                postcode => $handler->{data}{shipment_address}->postcode,
                state    => $handler->{data}{shipment_address}->county || $handler->{data}{shipment_address}->country,
            },
            {
                exclude_nominated_day   => $exclude_nominated_day,
                always_keep_sku         => $always_keep_sku,
                customer_facing_only    => $customer_facing_only,
                exclude_for_shipping_attributes => $pre_order->get_item_shipping_attributes,
            }
        );

        # these will appear on the confirmation page
        # where the user can choose the one they want
        $handler->{data}{shipment_options} = [ values %shipment_options ];

        # now update the Pre-Order's 'shipping_charge_id' field if required
        # to do so, the update further down to update the total value will
        # write these changes to the DB at the same time as the total value
        my $need_to_update  = (
               $just_created_new_pre_order                                          # if it's a brand new Pre-Order
            || !defined $pre_order->shipping_charge_id                              # or current Shipping Charge Id is NULL
            || !exists( $shipment_options{ $pre_order->shipping_charge_id } )       # or current Shipping Charge Id is now unavailable
            ? 1                                                                     # then UPDATE
            : 0                                                                     # else leave alone
        );
        if ( $need_to_update ) {
            # just pick the first Shipping Option to use
            $pre_order->shipping_charge_id( $handler->{data}{shipment_options}[0]->{id} );
        }
    }
    catch {
        $logger->warn($_);
        $handler->{data}{shipment_options} = [];
    };

    $logger->debug('Calculating total value and updating PreOrder entry');
    $pre_order->update({
        total_value => $pre_order->pre_order_items->total_value
    });

    # update the tax information if this order requires it
    #
    # This isn't incorporated into the above loop because
    # get_product_selling_price() doesn't have a view of
    # the whole basket, and so may not be accurate
    #
    # Even if it could be done that way, it's more efficient to
    # do a single Vertex request on the whole pre-order than it is to do
    # one request for every item in the basket, bearing in mind that each
    # Vertex request hits a service outside of XT
    #
    if ( $pre_order->use_vertex ) {
        my $quotation;

        try {
            $logger->debug( 'Getting vertex quotation for pre-order' );

            $quotation = $pre_order->create_vertex_quotation;
        }
        catch {
            my $msg;

            if ( m/Unable to find any applicable tax areas.*asOfDate. (?:\((?<address_info>.*)\))?/s ) {
                # a bogus address has been provided
                if ( $+{address_info} ) {
                    # and we've been able to capture what was interpreted as the address information
                    # pockle it to look right;

                    $msg = sprintf "%s: %s", $RESERVATION_MESSAGE__NOT_A_VALID_VERTEX_ADDRESS, $+{address_info};
                }
                else {
                    # best we can do is show the whole thing in this case
                    $msg = sprintf "%s: %s", $RESERVATION_MESSAGE__NOT_A_VALID_VERTEX_ADDRESS, $_;
                }

                xt_warn( $msg );
            }
            else {
                $msg = sprintf "%s: Vertex error is: %s", $RESERVATION_MESSAGE__CANT_GET_TAX_INFO, $_;

                xt_warn( $msg );
            }

            $logger->warn( $msg );
        };

        if ( $quotation ) {
            try {
                $logger->debug( 'Updating pre-order from vertex quotation' );

                $pre_order->update_from_vertex_quotation( $quotation );
            }
            catch {
                # this is more severe than the previous problems,
                # because if we have a valid quotation, we need to use it

                $logger->warn( $_ );
                xt_die( $RESERVATION_MESSAGE__UNABLE_TO_UPDATE_TAX_INFO );
            };
        }
    }

    # make sure the Pre-Order record is up to date
    $pre_order->discard_changes;

    # and finally, update exported handler data
    foreach my $item ($pre_order->pre_order_items->all) {
        my $unit_price = $item->unit_price || 0;
        my $tax        = $item->tax   || 0;
        my $duty       = $item->duty  || 0;

        my $total = $unit_price + $tax + $duty;
        if( ! exists $handler->{data}{variants}{$item->variant_id}{price} ) {
            $handler->{data}{variants}{$item->variant_id}{quantity} = 1;
            $handler->{data}{variants}{$item->variant_id}{price} = {
                     unit_price  => $unit_price,
                     duty   => $duty,
                     tax    => $tax,
                     total  => $total,
            };
       } else {
            $handler->{data}{variants}{$item->variant_id}{quantity}++;
            $handler->{data}{variants}{$item->variant_id}{price} = {
                unit_price  => $unit_price + $handler->{data}{variants}{$item->variant_id}{price}{unit_price},
                duty        => $duty       + $handler->{data}{variants}{$item->variant_id}{price}{duty},
                tax         => $tax        + $handler->{data}{variants}{$item->variant_id}{price}{tax},
                total       => $total      + $handler->{data}{variants}{$item->variant_id}{price}{total},
            };
        }
    }

    # For the output
    foreach my $variant_id ( keys %{$handler->{data}{variants}} ) {
        my $price = $handler->{data}{variants}{$variant_id}{price};
        $price->{unit_price} = format_currency_2dp($price->{unit_price});
        $price->{duty}       = format_currency_2dp($price->{duty});
        $price->{tax}        = format_currency_2dp($price->{tax});
        $price->{total}      = format_currency_2dp($price->{total});
    }

    $handler->{data}{payment_due}    = format_currency_2dp( $pre_order->total_value );
    $handler->{data}{original_total} = $pre_order->get_total_without_discount_formatted
                                                if ( $pre_order->applied_discount_percent );

    # Drag the parameters across
    $handler->{data}{params} = $handler->{param_of};

    return $handler->process_template;
}


sub _get_product_selling_price_tax_duty {
    my ( $self, $customer, $product, $discount_to_apply ) = @_;

    $discount_to_apply //= 0;
    my $handler = $self->{handler};

    # Get price for product
    my ($unit_price, undef, undef) = get_product_selling_price($handler->dbh, {
        customer_id       => $customer->id,
        product_id        => $product->id,
        county            => $handler->{data}{shipment_address}->county,
        country           => $handler->{data}{shipment_address}->country,
        order_currency_id => $handler->{data}{currency}{id},
        order_total       => 0,
        pre_order_discount => $discount_to_apply,
    });

    # Get tax and duty for product
    # Note that tax information may get blitzed by Vertex in a minute...
    #
    my (undef, $tax, $duty) = get_product_selling_price($handler->dbh, {
        customer_id       => $customer->id,
        product_id        => $product->id,
        county            => $handler->{data}{shipment_address}->county,
        country           => $handler->{data}{shipment_address}->country,
        order_currency_id => $handler->{data}{currency}{id},
        order_total       => $unit_price,
        pre_order_discount => $discount_to_apply,
    });

    return {
        unit_price => $unit_price,
        tax        => $tax,
        duty       => $duty,
    };
}

1;
