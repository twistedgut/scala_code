package XTracker::Order::Actions::ConfirmAddress;

use NAP::policy;

use DateTime::Format::Pg;
use DateTime::Format::HTTP;

use XTracker::Handler;
use XTracker::Error;
use XTracker::Database::Shipment qw(
    calc_shipping_charges
    check_shipment_restrictions
    get_order_shipment_info
    get_shipment_info
    get_shipment_item_info
    get_shipment_promotions
    get_similar_shipping_charge_info
);
use XTracker::Logfile qw(xt_logger);
use XTracker::Config::Local qw( config_var );
use XTracker::Database::Shipment;
use XTracker::Database::Order;
use XTracker::Database::Address;
use XTracker::Database::Currency;
use XTracker::Database::OrderPayment qw( get_order_payment check_order_payment_fulfilled );
use XTracker::Database::Pricing qw ( get_product_selling_price );
use XTracker::Database::Channel qw(get_channel_details);
use XTracker::DBEncode qw( decode_db );

use XTracker::DHL::RoutingRequest qw( get_routing_request_log );

use XTracker::EmailFunctions;
use XTracker::Constants::Address    qw( :address_update_messages );
use XTracker::Constants::FromDB qw( :correspondence_templates :department :shipment_item_status );
use XTracker::Config::Local qw( config_var customercare_email );
use XTracker::Utilities qw( parse_url number_in_list );
use XTracker::Database::Row;
use XTracker::Order::Functions::Shipment::EditShipment qw/
    json
    get_sku_current_and_available_nominated_delivery_dates
    get_shipping_options
    json_from_sku_available_dates
    get_nominated_day_shipping_options
/;

use XT::Net::Seaview::Client;

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);
    my $schema      = $handler->{schema};

    $handler->{data}{SHIPMENT_ITEM_STATUS__NEW}=$SHIPMENT_ITEM_STATUS__NEW;
    $handler->{data}{SHIPMENT_ITEM_STATUS__SELECTED}=$SHIPMENT_ITEM_STATUS__SELECTED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PICKED}=$SHIPMENT_ITEM_STATUS__PICKED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PACKED}=$SHIPMENT_ITEM_STATUS__PACKED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION}=$SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION;

    # Put Seaview client into handler
    $handler->{seaview} = XT::Net::Seaview::Client->new({schema => $schema});

    # get instance of XT (INTL or AM)
    my $instance = config_var('XTracker', 'instance');

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'ordertracker/shared/confirmaddress.tt';
    $handler->{data}{short_url}     = $short_url;
    $handler->{data}{css}           = ['/css/shipping_restrictions.css', '/css/breadcrumb.css'];

    # get the list of available countries from the database for select box
    $handler->{data}{countries} = get_country_list( $handler->{dbh} );

    # use country name as hash key so we can sort alphabetically
    foreach my $id ( keys %{ $handler->{data}{countries} } ){
        $handler->{data}{sorted_countries}{ $handler->{data}{countries}{$id}{country} } = $id;
    }

    # get order id from url
    # get shipment id from url
    # get what type of address we're editing from the url (billing or shipping)
    $handler->{data}{order_id}      = $handler->{param_of}{order_id};
    $handler->{data}{address_type}  = $handler->{param_of}{address_type};
    $handler->{data}{shipment_id}   = $handler->{param_of}{shipment_id};
    # indicates whether the 'Force' option is shown on the final confirmation page
    $handler->{data}{can_show_force_address} = $handler->{param_of}{can_show_force_address};

    my $order_obj;
    if ( $handler->{data}{order_id} ) {
        $order_obj = $handler->schema->resultset('Public::Orders')
                                        ->find( $handler->{data}{order_id} );
    }

    # The address source could be one of two forms. Everyone is sad.
    if($handler->{param_of}{base_address}){
        $handler->{data}{base_address}  = $handler->{param_of}{base_address};
    }
    else{
        $handler->{data}{base_address}  = $handler->{param_of}{address};
    }

    # Clear the title
    $handler->{data}{layout}{notitle} = 1;

    # URL for the Back Link
    my $go_back_url = $short_url . '/ChooseAddress';

    # we're editing a billing address
    if ($handler->{data}{address_type} eq "Billing"){
        $handler->{data}{subsubsection} = 'Edit Billing Address';

        # Breadcrumb
        $handler->{data}{breadcrumb}{steps}
          = ['1. Change Address','2. Confirmation'];
        $handler->{data}{breadcrumb}{current} = '2. Confirmation';

        # back link in left nav
        $go_back_url .= '?address_type=Billing'
                      . '&order_id=' . $handler->{data}{order_id};

        # back link in left nav
        push(@{ $handler->{data}{sidenav}[0]{'None'} },
             { 'title' => 'Back', 'url' => $go_back_url });

        $handler->{data}{subsubsection}     = 'Edit Billing Address';
        $handler->{data}{order_data}        = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
        $handler->{data}{sales_channel}     = $handler->{data}{order_data}{sales_channel};
        $handler->{data}{current_address}   = get_address_info( $schema, $handler->{data}{order_data}{invoice_address_id} );

    }
    # we're editing a shipping address
    elsif ($handler->{data}{address_type} eq "Shipping"){
        $handler->{data}{subsubsection} = 'Edit Shipping Address';

        # Breadcrumb
        $handler->{data}{breadcrumb}{steps}
          = ['1. Change Address','2. Check Order','3. Confirmation'];
        $handler->{data}{breadcrumb}{current} = '2. Check Order';

        if ( $order_obj && $order_obj->payment_method_insists_billing_and_shipping_address_always_the_same ) {
            xt_info( $ADDRESS_UPDATE_MESSAGE__BILLING_AND_SHIPPING_ADDRESS_SAME );
        }

        # back link in left nav
        $go_back_url .= '?address_type=Shipping'
                      . '&shipment_id=' . $handler->{data}{shipment_id}
                      . '&order_id=' . $handler->{data}{order_id};

        push(@{ $handler->{data}{sidenav}[0]{'None'} },
             { 'title' => 'Back', 'url' => $go_back_url });

        # if we have a shipment id in the URL get the info we need
        if ( $handler->{data}{shipment_id} ) {

            $handler->{data}{order_data}        = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
            $handler->{data}{sales_channel}     = $handler->{data}{order_data}{sales_channel};
            $handler->{data}{shipment_data}     = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
            $handler->{data}{shipment_items}    = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );
            $handler->{data}{current_address}   = get_address_info( $schema, $handler->{data}{shipment_data}{shipment_address_id} );
            $handler->{data}{routing_request}   = get_routing_request_log( $handler->{dbh}, $handler->{data}{shipment_id} );
            $handler->{data}{promotions}        = get_shipment_promotions( $handler->{dbh}, $handler->{data}{shipment_id} );

        }
        else {
            # No shipment id - redirect to order with message??
        }
    }
    # no other address type to edit ??
    else {
        # Bad address type - redirect to order with message??
        # die "Unknown address type - $handler->{data}{address_type}";
    }

    ##############################################################
    # We have a new address and have gathered the address details.
    # Now process the address change.
    ##############################################################

    # get correct from email address for channel
    my $customer                    = $schema->resultset('Public::Customer')->find( $handler->{data}{order_data}->{customer_id} );
    $handler->{data}{customer_rec}  = $customer;
    $handler->{data}{channel}       = get_channel_details( $handler->{dbh}, $handler->{data}{order_data}{sales_channel} );
    $handler->{data}{from_email}    = customercare_email( $handler->{data}{channel}{config_section}, {
        schema => $schema,
        locale => $customer->locale,
    } );

    # new address submitted - recalculate pricing
    $handler->{data}->{from_select_shipping_option} = $handler->{param_of}{select_shipping_option};
    $handler->{data}->{from_edit_address}           = $handler->{param_of}{edit_address};

    if( $handler->{param_of}{edit_address}) {
        # Move current breadcrumb state on
        $handler->{data}{breadcrumb}{current} = '3. Confirmation';
    }

    if ( $handler->{param_of}{select_shipping_option} || $handler->{param_of}{edit_address} ) {
        my $channel_id = $handler->{data}{order_data}{channel_id};
        my $channel = $schema->find(Channel => $channel_id);

        $handler->{data}{new_address} = get_old_or_new_address_info(
            $schema,
            $handler->{param_of},
            $handler->{seaview},
        );
        # workaround for email templates    - pass 'new_address' hash into 'shipment_address' hash
        $handler->{data}{shipment_address} = $handler->{data}{new_address};

        # get the id and code of the country in the new address - may need it later
        my $country = $schema->resultset('Public::Country')->find_by_name( $handler->{data}{new_address}{country} );
        if ( !$country ) {
            xt_warn( sprintf( "Invalid Country - '%s'", ( $handler->{data}{new_address}{country} || 'undefined' ) ) );
            return $handler->redirect_to( $go_back_url );
        }
        $handler->{data}{new_country_id}   = $country->id;
        $handler->{data}{new_country_code} = $country->code;

        # default price difference variable to 0
        $handler->{data}{price_difference} = "0.00";

        # extra steps required for Shipping address changes only
        if($handler->{data}{address_type} eq 'Shipping') {

            my $current_new_shipping_option = get_current_new_shipping_option(
                $schema,
                $channel,
                $handler->{data},
                $handler->{data}{shipment_data},
                $handler->{data}{shipment_items},
                $handler->{data}{new_address},
            );
            @{ $handler->{data} }{keys %$current_new_shipping_option}
                = values %$current_new_shipping_option;

            my $selected_shipping_option = get_selected_shipping_option(
                $schema,
                $current_new_shipping_option->{new_shipping_option}->{shipping_charges},
                $handler->{param_of},
            );
            @{ $handler->{data}->{new_shipping_option} }{keys %$selected_shipping_option}
                = values %$selected_shipping_option;


            my $has_address_changed = has_address_changed(
                $handler->{dbh},
                $handler->{data}{current_address},
                $handler->{data}{new_address},
            );
            if( $has_address_changed ) {

                # Get the restrictions that apply for this shipment going to the
                # new address.

                my $restrictions = check_shipment_restrictions( $schema, {
                    shipment_id => $handler->{data}{shipment_id},
                    address_ref => {
                        county       => $handler->{data}{new_address}{county},
                        postcode     => $handler->{data}{new_address}{postcode},
                        country      => $country->country,
                        country_code => $country->code,
                        sub_region   => $country->sub_region->sub_region,
                    },
                    # don't want to send an email yet as the change
                    # of address hasn't been confirmed yet
                    never_send_email => 1,
                } );

                if ( $restrictions->{restrict} ) {
                    # If there are restrictions, inform the user and go no further.
                    # To inform the user, we will add a Shipment Items list to the
                    # page with a restriction flag.
                    my $restricted_products = $restrictions->{restricted_products};

                    xt_warn( "Cannot update address, order contains restricted products (see below) which can't be delivered there." );

                    # Clear the new address, so the template displays the correct page.
                    $handler->{data}{new_address} = undef;
                    $handler->{data}{restrictions} = 1;

                    # Set the restrictions.
                    foreach my $ship_item ( values %{ $handler->{data}{shipment_items} } ) {
                        my ( $product_id ) = split /-/, $ship_item->{sku};
                        $ship_item->{restricted}         = (
                            exists( $restricted_products->{ $product_id } )
                            && $restricted_products->{ $product_id }{actions}{restrict}
                            ? 1
                            : 0
                        );
                        $ship_item->{restricted_details} = $restricted_products->{ $product_id };
                    }

                    # We're done.
                    return $handler->process_template( undef );
                }

                my $shipment_obj = $schema->resultset('Public::Shipment')->find( $handler->{data}{shipment_id} );
                my $new_flag = $shipment_obj->get_allowed_value_of_signature_required_flag_for_address({
                    department_id           => $handler->{data}{department_id},
                    signature_required_flag => $shipment_obj->signature_required,
                    address                 => $handler->{data}{new_address},
                });
               # Only update if it has changed
                if( $shipment_obj->signature_required != $new_flag ) {
                    $handler->{data}{can_show_signature_flag} = 1;
                    $handler->{data}{new_signature_required_flag } = $new_flag;
                    $handler->{data}{current_signature_required_flag } = $shipment_obj->signature_required;
                }


                try {
                    check_fulfilment_only_country_change(
                        $handler->{data}{channel},
                        $handler->{data}{current_address},
                        $handler->{data}{new_address},
                    );
                }
                catch {
                    xt_warn( $_ );
                    $handler->{data}{new_address} = undef;
                    $handler->{param_of}{edit_address} = undef;
                    $handler->{data}{breadcrumb}{current} = '1. Change Address';
                };

                if($handler->{param_of}{edit_address}) {

                    my $should_recalculate_items_or_shipping_pricing
                        = should_recalculate_items_or_shipping_pricing(
                            $handler->{data}{current_address},
                            $handler->{data}{new_address},
                            $handler->{data}{shipment_data}{shipping_charge_id},
                            $selected_shipping_option->{selected_shipping_charge_id},
                        );
                    # check for pricing changes for channels where we
                    # have pricing informatin (e.g. not JC)
                    if (        $should_recalculate_items_or_shipping_pricing
                             && !$handler->{data}{channel}{fulfilment_only} ) {
                        recalculate_items_or_shipping_pricing(
                            $schema,
                            $handler->{data},
                        );
                    }
                }
            }
        }
    }


    return $handler->process_template( undef );
}

sub maybe_datestamp_as_human {
    my ($datestamp) = @_;
    $datestamp or return "";
    return $datestamp->human;
}

sub get_old_or_new_address_info {
    my ($schema, $param_of, $seaview) = @_;

    # user selected one of the customers previous addresses
    if ( $param_of->{address} && $param_of->{address} ne 'new' ) {
        my $address_info = undef;

        # Seaview: If the old address reference is a URN then this is a
        # central record - get the details from the service
        if($seaview->service->seaview_resource($param_of->{address})){
            $address_info = $seaview->address($param_of->{address})
                                    ->as_dbi_like_hash;
        }
        else{
            $address_info = get_address_info($schema, $param_of->{address});
        }

        return $address_info;
    }

    # user edited current address
    my $address = {
        first_name     => $param_of->{first_name},
        last_name      => $param_of->{last_name},
        address_line_1 => $param_of->{address_line_1},
        address_line_2 => $param_of->{address_line_2},
        address_line_3 => $param_of->{address_line_3},
        towncity       => $param_of->{towncity},
        county         => $param_of->{county},
        postcode       => $param_of->{postcode},
        # little workaround for old addresses where country isn't in country table
        country        => $param_of->{country} || $param_of->{nomatch_country},
    };

    $address->{urn} = $param_of->{urn} if defined $param_of->{urn};

    $address->{last_modified}
      = $param_of->{last_modified} if defined $param_of->{last_modified};

    return $address;
}

# we shouldn't be changing shipping country for fulfilment only businesses
sub check_fulfilment_only_country_change {
    my ($channel, $current_address, $new_address) = @_;

    if (
        $channel->{fulfilment_only}
        &&
        $new_address->{country} ne $current_address->{country}
    ) {
        die "Cannot change shipping country for a 'fulfilment only' business.";
    }
}

sub get_current_new_shipping_option {
    my ($schema, $channel, $data, $shipment_data, $shipment_items, $new_address) = @_;

    my $dbh = $schema->storage->dbh;

    my $shipment_obj    = $schema->resultset('Public::Shipment')
                                    ->find( $shipment_data->{id} );

    my $nominated_delivery_date_human = maybe_datestamp_as_human(
        $shipment_data->{nominated_delivery_date}
    );
    my $premier_routing_description =
        $shipment_data->{shipping_charge_premier_routing_id}
            ? $shipment_data->{premier_routing_description}
            : "";
    my $current_shipping_option = {
        shipping_charge_description   => $shipment_data->{shipping_name},
        nominated_delivery_date_human => $nominated_delivery_date_human,
        premier_routing_description   => $premier_routing_description,
    };

    my $nominated_day_shipping_options = get_nominated_day_shipping_options(
        $dbh,
        $channel,
        $data,
        $shipment_data,
        $shipment_items,
        $new_address,
        $shipment_obj,
    );
    my $default_shipping_charge_id = get_default_shipping_charge_id(
        $dbh,
        $channel->id,
        $shipment_data,
        $new_address,
        $shipment_obj,
    );
    my $new_shipping_option = {
        %$nominated_day_shipping_options,
        default_shipping_charge_id => $default_shipping_charge_id,
    };

    return {
        current_shipping_option => $current_shipping_option,
        new_shipping_option     => $new_shipping_option,
    };
}

sub get_default_shipping_charge_id {
    my ($dbh, $channel_id, $shipment_data, $new_address, $shipment_obj) = @_;

    my $default_shipping_charge_info = get_similar_shipping_charge_info(
        $dbh,
        {
            country            => $new_address->{country},
            county             => $new_address->{county},
            postcode           => $new_address->{postcode},
            shipping_charge_id => $shipment_data->{shipping_charge_id},
            shipping_class_id  => $shipment_data->{shipping_class_id},
            channel_id         => $channel_id,
            shipment_obj       => $shipment_obj,
        },
        my $customer_facing_only = 1,
    ) or return "";
    return $default_shipping_charge_info->{id};
}

sub get_selected_shipping_option {
    my ($schema, $shipping_charges, $param_of) = @_;

    # Return value
    my $selected_shipping_charge_id
        = $param_of->{selected_shipping_charge_id}
            // return { };

    my $selected_shipping_charge
        = $shipping_charges->{$selected_shipping_charge_id}
            or die("Unknown shipping charge id ($selected_shipping_charge_id)\n");

    # Return value
    my $selected_premier_routing_description = get_premier_routing_description(
        $schema,
        $selected_shipping_charge->{premier_routing_id},
    );

    # Return value
    my $selected_nominated_delivery_date_str = $param_of->{selected_nominated_delivery_date};
    if ( !$selected_shipping_charge->{latest_nominated_dispatch_daytime} ) {
        # Not a Nominated Day Shipping Charge, clear the passed in date
        $selected_nominated_delivery_date_str = undef;
    }
    my $selected_nominated_delivery_date
        = XTracker::Database::Row->transform(
            $selected_nominated_delivery_date_str,
            "DateStamp",
        );

    # Return value
    my $selected_nominated_delivery_date_human = maybe_datestamp_as_human(
        $selected_nominated_delivery_date,
    );

    return {
        selected_shipping_charge_id            => $selected_shipping_charge_id,
        selected_premier_routing_description   => $selected_premier_routing_description,
        selected_nominated_delivery_date       => $selected_nominated_delivery_date,
        selected_nominated_delivery_date_human => $selected_nominated_delivery_date_human,
    };
}

sub get_premier_routing_description {
    my ($schema, $premier_routing_id) = @_;
    my $premier_routing_row = $schema->find(
        PremierRouting => $premier_routing_id,
    ) or return "";
    return $premier_routing_row->description;
}

sub has_address_changed {
    my ($dbh, $current_address, $new_address) = @_;
    return $current_address->{address_hash} ne hash_address($dbh, $new_address);
}

sub should_recalculate_items_or_shipping_pricing {
    my ($current_address, $new_address, $current_shipping_charge_id, $new_shipping_charge_id) = @_;

    return 1 if($current_shipping_charge_id != $new_shipping_charge_id);

    return should_recalculate_items_pricing($current_address, $new_address);
}

sub should_recalculate_items_pricing {
    my ($current_address, $new_address) = @_;

    return 1 if($current_address->{country} ne $new_address->{country});

    if( $current_address->{country} eq "United States" ) {
        return 1 if($current_address->{county} ne $new_address->{county});
    }

    return 0;
}

sub recalculate_items_or_shipping_pricing {
    my ($schema, $data) = @_;

    my $dbh = $schema->storage->dbh;

    # flag if payment has been taken yet
    $data->{payment} = check_order_payment_fulfilled(
        $dbh,
        $data->{order_id},
    );

    # We need the shipment object for the email templates.
    my $shipment = $schema
        ->resultset('Public::Shipment')
        ->find( $data->{shipment_data}{id} );

    # Process the email template.
    my $email_info = get_and_parse_correspondence_template(
        $schema,
        $CORRESPONDENCE_TEMPLATES__CONFIRM_PRICE_CHANGE__1,
        {
            channel  => $shipment->get_channel,
            data     => {
                # Make sure we have the order_number just for the email
                # template and not in the main $data structure.
                order_number => $data->{order_data}{order_nr},
                %$data
            },
            base_rec => $shipment,
        }
    );

    # Populate the HTML page template.
    $data->{email_subject}      = $email_info->{subject};
    $data->{email_content}      = $email_info->{content};
    $data->{email_content_type} = $email_info->{content_type};

    # get the current and new prices
    eval {
        _get_pricing_data( $dbh, $data );
    };
    if ($@) {
        $data->{error_msg} = $@;
        delete($data->{new_address});
    }

}

sub _get_pricing_data {
    my ( $dbh, $data ) = @_;

    $data->{order_total}   = 0;
    $data->{current_total} = 0;
    $data->{new_total}     = 0;
    $data->{item_count}    = 0;

    # calculate current order total for duty thresholds
    for my $item_id ( keys %{ $data->{shipment_items} } ) {
        my $shipment_item = $data->{shipment_items}->{$item_id};
        is_shipment_item_active($shipment_item) or next;
        $data->{order_total} += $shipment_item->{unit_price};
    }

    my $should_update_items_pricing = should_recalculate_items_pricing(
        $data->{current_address},
        $data->{new_address},
    );

    # loop through shipment items to get current and new prices
    for my $item_id ( keys %{ $data->{shipment_items} } ) {
        my $shipment_item = $data->{shipment_items}->{$item_id};
        is_shipment_item_active($shipment_item) or next;

        # check for promotional discounts on item
        my $promotion_percentage = get_shipment_item_promotion_percentage(
            $shipment_item,
            $data->{promotions},
        );

        # sort out current prices
        $shipment_item->{unit_price} = _d2($shipment_item->{unit_price});
        $shipment_item->{tax}        = _d2($shipment_item->{tax});
        $shipment_item->{duty}       = _d2($shipment_item->{duty});

        $data->{current_total} +=
              $shipment_item->{unit_price}
            + $shipment_item->{tax}
            + $shipment_item->{duty};


        $shipment_item->{new_unit_price} = $shipment_item->{unit_price};
        $shipment_item->{new_tax}        = $shipment_item->{tax};
        $shipment_item->{new_duty}       = $shipment_item->{duty};

        if($should_update_items_pricing) {
            # get new prices for new address
            (
                $shipment_item->{new_unit_price},
                $shipment_item->{new_tax},
                $shipment_item->{new_duty},
            ) = get_product_selling_price(
                $dbh,
                {
                    product_id        => $shipment_item->{product_id},
                    county            => $data->{new_address}{county},
                    country           => $data->{new_address}{country},
                    order_currency_id => $data->{order_data}{currency_id},
                    customer_id       => $data->{order_data}{customer_id},
                    order_total       => $data->{order_total},
                },
            );

            # apply promotional discount if required
            if ($promotion_percentage) {

                $shipment_item->{promo_prices} = 1;

                # work out value of promotion
                $shipment_item->{promo_unit_price} = $promotion_percentage * $shipment_item->{new_unit_price};
                $shipment_item->{promo_tax}        = $promotion_percentage * $shipment_item->{new_tax};
                $shipment_item->{promo_duty}       = $promotion_percentage * $shipment_item->{new_duty};

                # take it off final prices
                $shipment_item->{new_unit_price} -= $shipment_item->{promo_unit_price};
                $shipment_item->{new_tax}        -= $shipment_item->{promo_tax};
                $shipment_item->{new_duty}       -= $shipment_item->{promo_duty};
            }
        }

        $shipment_item->{new_unit_price} = _d2($shipment_item->{new_unit_price});
        $shipment_item->{new_tax}        = _d2($shipment_item->{new_tax});
        $shipment_item->{new_duty}       = _d2($shipment_item->{new_duty});

        $data->{new_total} +=
                  $shipment_item->{new_unit_price}
                + $shipment_item->{new_tax}
                + $shipment_item->{new_duty};

        $data->{item_count}++;
    }

    # add shipping to current and new totals
    $data->{current_total} += $data->{shipment_data}{shipping_charge};

    # clean up the shipping for display on the page
    $data->{shipment_data}{shipping_charge} = _d2($data->{shipment_data}{shipping_charge});


    ##########
    # calculate the new shipping charge
    ##########

    if ( $data->{customer_rec}->should_not_have_shipping_costs_recalculated ) {
        # for some Customer Categories (EIPs) the actual Shipping Cost
        # doesn't change even if a different Shipping Option is used
        $data->{new_shipping_charge} = $data->{shipment_data}{shipping_charge};
    }
    else {
        my %shipping_param = (
            country            => $data->{new_address}{country},
            county             => $data->{new_address}{county},
            postcode           => $data->{new_address}{postcode},
            item_count         => $data->{item_count},
            order_total        => $data->{new_total},
            order_currency_id  => $data->{order_data}{currency_id},
            # The Shipping Charge we're about to change to
            shipping_charge_id => $data->{new_shipping_option}->{selected_shipping_charge_id},
            shipping_class_id  => $data->{shipment_data}{shipping_class_id},
            channel_id         => $data->{order_data}{channel_id},
        );
        $data->{new_shipping} = calc_shipping_charges($dbh, \%shipping_param);
        $data->{new_shipping_charge} = _d2($data->{new_shipping}{charge});
    }

    if ($data->{new_shipping_charge} == 0){
        $data->{new_shipping_charge} = "0.00";
    }

    ############
    # finished calculating the new shipping charge
    ############


    $data->{new_total} += $data->{new_shipping_charge};


    $data->{price_difference} = $data->{new_total} - $data->{current_total};

    $data->{new_total}        = _d2($data->{new_total});
    $data->{current_total}    = _d2($data->{current_total});
    $data->{price_difference} = _d2($data->{price_difference});
}

sub is_shipment_item_active {
    my ($shipment_item) = @_;
    return number_in_list(
        $shipment_item->{shipment_item_status_id},
        $SHIPMENT_ITEM_STATUS__NEW,
        $SHIPMENT_ITEM_STATUS__SELECTED,
        $SHIPMENT_ITEM_STATUS__PICKED,
        $SHIPMENT_ITEM_STATUS__PACKED,
        $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
    );
}

sub get_shipment_item_promotion_percentage {
    my ($shipment_item, $name_promotion) = @_;

    my $item_id = $shipment_item->{id};
    my $promotion_percentage;
    for my $promotion ( values %$name_promotion ) {
        my $item = $promotion->{items}{$item_id} or next;

        my $discount =          $item->{unit_price};
        my $paid     = $shipment_item->{unit_price};
        $promotion_percentage = _d2( $discount / ( $discount + $paid ) );
    }

    return $promotion_percentage;
}

sub seaview_addresses {
    my ($handler, $account_urn) = @_;
    my $customer_urn = undef;

    try{
        # Pull address list from Seaview
        $customer_urn = $handler->{seaview}->find_customer($account_urn);
    }
    catch {
        # Handle Seaview exceptions
        xt_logger->info($_);
    };

    return { map { $_->urn => $_->as_dbi_like_hash }
                 values %{$handler->{seaview}->all_addresses($customer_urn)//{}}
           };
}

# Subroutine : _d2                            #
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _d2 {
    my $val = shift;
    my $n = sprintf( "%.2f", $val );
    return $n;
}

1;
