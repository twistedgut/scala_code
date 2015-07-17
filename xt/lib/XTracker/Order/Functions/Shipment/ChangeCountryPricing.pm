package XTracker::Order::Functions::Shipment::ChangeCountryPricing;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Shipment qw(
    check_shipment_restrictions
    :DEFAULT
);
use XTracker::Database::Order;
use XTracker::Database::Address;
use XTracker::Database::Pricing qw (get_product_selling_price);
use XTracker::Database::Currency;
use XTracker::Database::OrderPayment qw( check_order_payment_fulfilled );
use XTracker::Database::Channel qw(get_channel_details);

use XTracker::Utilities qw( parse_url number_in_list );
use XTracker::EmailFunctions;
use XTracker::Constants::FromDB qw( :correspondence_templates :shipment_item_status );
use XTracker::Config::Local qw( customercare_email );
use XTracker::Error;

use Try::Tiny;

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{SHIPMENT_ITEM_STATUS__NEW}=$SHIPMENT_ITEM_STATUS__NEW;
    $handler->{data}{SHIPMENT_ITEM_STATUS__SELECTED}=$SHIPMENT_ITEM_STATUS__SELECTED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PICKED}=$SHIPMENT_ITEM_STATUS__PICKED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PACKED}=$SHIPMENT_ITEM_STATUS__PACKED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION}=$SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION;

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Confirm Pricing';
    $handler->{data}{short_url}     = $short_url;
    $handler->{data}{content}       = 'ordertracker/shared/changecountrypricing.tt';
    $handler->{data}{css}           = ['/css/shipping_restrictions.css'];

    # get params from url
    $handler->{data}{order_id}      = $handler->{request}->param('order_id');
    $handler->{data}{shipment_id}   = $handler->{request}->param('shipment_id');
    $handler->{data}{action}        = $handler->{request}->param('action');

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "$short_url/OrderView?order_id=$handler->{data}{order_id}" } );

    # get order info
    my $order_obj                       = $handler->schema->resultset('Public::Orders')->find( $handler->{data}{order_id} );
    $handler->{data}{order}             = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{sales_channel}     = $handler->{data}{order}{sales_channel};
    $handler->{data}{payment}           = check_order_payment_fulfilled( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{channel}           = get_channel_details( $handler->{dbh}, $handler->{data}{order}{sales_channel} );
    $handler->{data}{invoice_address}   = get_address_info( $handler->{dbh}, $handler->{data}{order}{invoice_address_id} );

    # from email addresses out of config file
    $handler->{data}{customercare_email} = customercare_email( $handler->{data}{channel}{config_section}, {
        schema  => $handler->schema,
        locale  => ( $order_obj ? $order_obj->customer->locale : '' ),
    } );

    # get shipment info
    if ($handler->{data}{shipment_id}){

        my $shipment_obj                        = $handler->{schema}->resultset('Public::Shipment')->find( $handler->{data}{shipment_id} );
        $handler->{data}{shipment}              = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{order_id}              = get_shipment_order_id( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{shipment_address}      = get_address_info( $handler->{dbh}, $handler->{data}{shipment}{shipment_address_id} );
        $handler->{data}{shipment_item}         = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{shipment_country_id}   = _get_country_id( $handler->{dbh}, $handler->{data}{shipment_address}{country} );
        $handler->{data}{current_country}       = $handler->{data}{shipment_address}{country};
        $handler->{data}{new_country}           = $handler->{data}{shipment_address}{country};
        $handler->{data}{promotions}            = get_shipment_promotions( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{current_county}        = $handler->{data}{shipment_address}{county};
        $handler->{data}{current_postcode}      = $handler->{data}{shipment_address}{postcode};

        # check pricing function
        if ($handler->{data}{action} eq 'Check'){

            # customer email - if required
            if ( $handler->{request}->param('send_email') && $handler->{request}->param('send_email') eq 'yes' ){

                my $email_sent  = send_customer_email( {
                    to          => $handler->{param_of}{'email_to'},
                    from        => $handler->{param_of}{'email_from'},
                    reply_to    => $handler->{param_of}{'email_replyto'},
                    subject     => $handler->{param_of}{'email_subject'},
                    content     => $handler->{param_of}{'email_body'},
                    content_type => $handler->{param_of}{'email_content_type'},
                } );

                if ($email_sent == 1){
                    log_shipment_email( $handler->{dbh}, $handler->{data}{shipment_id}, $CORRESPONDENCE_TEMPLATES__REQUEST_PRICE_CHANGE_CONFIRMATION__1, $handler->{data}{operator_id} );
                }

                return $handler->redirect_to( "$short_url/OrderView?order_id=$handler->{data}{order_id}" );
            }

            $handler->{data}{check_pricing} = 1;
            $handler->{data}{subsubsection} = 'Check Country Pricing';
            $handler->{data}{countries}     = _get_country_list($handler->{dbh});

            # new country submitted
            if ( $handler->{request}->param('country') ){
                $handler->{data}{check_country}             = $handler->{request}->param('country');
                $handler->{data}{new_country}               = $handler->{request}->param('country');
                $handler->{data}{shipment_country_id}       = _get_country_id( $handler->{dbh}, $handler->{data}{check_country} );
                $handler->{data}{shipment_address}{country} = $handler->{data}{check_country};
            }

            my $county  = $handler->{data}{current_county};
            if ( $handler->{request}->param('county')
                 # if the country has changed then should get a new county even if it's blank
                 || ( $handler->{data}{new_country} ne $handler->{data}{current_country} ) ) {
                $county = $handler->{request}->param('county');
                $handler->{data}{check_county}             = $county;
                $handler->{data}{shipment_address}{county} = $county // '';
            }
            $handler->{data}{new_county} = $county;

            my $postcode = $handler->{data}{current_postcode};
            if ( $handler->{request}->param('postcode')
                 # if the country or county has changed then should get a new postcode even if it's blank
                 || ( $handler->{data}{new_country} ne $handler->{data}{current_country} )
                 || ( $county ne $handler->{data}{current_county} ) ) {
                $postcode = $handler->{request}->param('postcode');
                $handler->{data}{check_postcode}             = $postcode;
                $handler->{data}{shipment_address}{postcode} = $postcode // '';
             }
            $handler->{data}{new_postcode} = $postcode;

            my $country = $handler->{schema}->resultset('Public::Country')
                ->find_by_name( $handler->{data}{new_country} );

            # Get the restrictions that apply for this shipment going to the
            # new address.
            $handler->{data}{restrictions} = check_shipment_restrictions( $handler->{schema}, {
                shipment_id => $handler->{data}{shipment_id},
                address_ref => {
                    county       => $county   // '',
                    postcode     => $postcode // '',
                    country      => $country->country,
                    country_code => $country->code,
                    sub_region   => $country->sub_region->sub_region,
                },
                # don't want to send an email because
                # this is just speculation
                never_send_email => 1,
            } );

        }


        $handler->{data}{order_total}   = 0;
        $handler->{data}{current_total} = 0;
        $handler->{data}{new_total}     = 0;
        $handler->{data}{item_count}    = 0;

        # calculate current order total for duty thresholds
        foreach my $item_id ( keys %{ $handler->{data}{shipment_item} } ) {
            # only active items included
            if (number_in_list($handler->{data}{shipment_item}{$item_id}{shipment_item_status_id},
                                           $SHIPMENT_ITEM_STATUS__NEW,
                                           $SHIPMENT_ITEM_STATUS__SELECTED,
                                           $SHIPMENT_ITEM_STATUS__PICKED,
                                           $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                           $SHIPMENT_ITEM_STATUS__PACKED,
                                       ) ) {
                $handler->{data}{order_total} += $handler->{data}{shipment_item}{$item_id}{unit_price};
            }
        }

        # loop through shipment items to get current and new prices
        foreach my $item_id ( keys %{ $handler->{data}{shipment_item} } ) {

            # only active items included
            if (number_in_list($handler->{data}{shipment_item}{$item_id}{shipment_item_status_id},
                                   $SHIPMENT_ITEM_STATUS__NEW,
                                   $SHIPMENT_ITEM_STATUS__SELECTED,
                                   $SHIPMENT_ITEM_STATUS__PICKED,
                                   $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                   $SHIPMENT_ITEM_STATUS__PACKED,
                               ) ) {
                # first check for promotional discounts on item
                foreach my $promotion_name ( %{ $handler->{data}{promotions} } ) {
                    if ( exists $handler->{data}{promotions}{$promotion_name}{items}{$item_id} ) {
                        my $discount = $handler->{data}{promotions}{$promotion_name}{items}{$item_id}{unit_price};
                        my $paid     = $handler->{data}{shipment_item}{$item_id}{unit_price};
                        $handler->{data}{shipment_item}{$item_id}{promotion_percentage} = _d2( $discount / ( $discount + $paid ) );
                    }
                }

                # round current prices
                $handler->{data}{shipment_item}{$item_id}{unit_price}   = _d2($handler->{data}{shipment_item}{$item_id}{unit_price});
                $handler->{data}{shipment_item}{$item_id}{tax}          = _d2($handler->{data}{shipment_item}{$item_id}{tax});
                $handler->{data}{shipment_item}{$item_id}{duty}         = _d2($handler->{data}{shipment_item}{$item_id}{duty});

                # add to current total
                $handler->{data}{current_total} += $handler->{data}{shipment_item}{$item_id}{unit_price};
                $handler->{data}{current_total} += $handler->{data}{shipment_item}{$item_id}{tax};
                $handler->{data}{current_total} += $handler->{data}{shipment_item}{$item_id}{duty};

                # get new prices for new address
                ($handler->{data}{shipment_item}{$item_id}{new_unit_price}, $handler->{data}{shipment_item}{$item_id}{new_tax}, $handler->{data}{shipment_item}{$item_id}{new_duty})
                = get_product_selling_price( $handler->{dbh},
                                                {
                                                    'product_id'        => $handler->{data}{shipment_item}{$item_id}{product_id},
                                                    'county'            => $handler->{data}{new_county} // '',
                                                    'country'           => $handler->{data}{new_country},
                                                    'order_currency_id' => $handler->{data}{order}{currency_id},
                                                    'customer_id'       => $handler->{data}{order}{customer_id},
                                                    'order_total'       => $handler->{data}{order_total}
                                                }
                );

                # apply promotional discount if required
                if ($handler->{data}{shipment_item}{$item_id}{promotion_percentage}) {
                    # work out value of promotion
                    $handler->{data}{shipment_item}{$item_id}{promo_unit_price}   = $handler->{data}{shipment_item}{$item_id}{promotion_percentage} * $handler->{data}{shipment_item}{$item_id}{new_unit_price};
                    $handler->{data}{shipment_item}{$item_id}{promo_tax}          = $handler->{data}{shipment_item}{$item_id}{promotion_percentage} * $handler->{data}{shipment_item}{$item_id}{new_tax};
                    $handler->{data}{shipment_item}{$item_id}{promo_duty}         = $handler->{data}{shipment_item}{$item_id}{promotion_percentage} * $handler->{data}{shipment_item}{$item_id}{new_duty};

                    # take it off final prices
                    $handler->{data}{shipment_item}{$item_id}{new_unit_price}   -= $handler->{data}{shipment_item}{$item_id}{promo_unit_price};
                    $handler->{data}{shipment_item}{$item_id}{new_tax}          -= $handler->{data}{shipment_item}{$item_id}{promo_tax};
                    $handler->{data}{shipment_item}{$item_id}{new_duty}         -= $handler->{data}{shipment_item}{$item_id}{promo_duty};
                }

                # round new prices
                $handler->{data}{shipment_item}{$item_id}{new_unit_price}   = _d2($handler->{data}{shipment_item}{$item_id}{new_unit_price});
                $handler->{data}{shipment_item}{$item_id}{new_tax}          = _d2($handler->{data}{shipment_item}{$item_id}{new_tax});
                $handler->{data}{shipment_item}{$item_id}{new_duty}         = _d2($handler->{data}{shipment_item}{$item_id}{new_duty});

                # add to new total
                $handler->{data}{new_total} += $handler->{data}{shipment_item}{$item_id}{new_unit_price};
                $handler->{data}{new_total} += $handler->{data}{shipment_item}{$item_id}{new_tax};
                $handler->{data}{new_total} += $handler->{data}{shipment_item}{$item_id}{new_duty};

                # increment number of items
                $handler->{data}{item_count}++;
            }
        }

        # round shipping charge for display
        $handler->{data}{shipment}{shipping_charge} = _d2($handler->{data}{shipment}{shipping_charge});

        # add shipping charge to current total
        $handler->{data}{current_total} += $handler->{data}{shipment}{shipping_charge};

        try {
            # get new shipping charge
            my %shipping_param = (
                country             => $handler->{data}{shipment_address}{country},
                county              => $handler->{data}{shipment_address}{county},
                postcode            => $handler->{data}{shipment_address}{postcode},
                item_count          => $handler->{data}{item_count},
                order_total         => $handler->{data}{new_total},
                order_currency_id   => $handler->{data}{order}{currency_id},
                shipping_charge_id  => $handler->{data}{shipment}{shipping_charge_id},
                shipping_class_id   => $handler->{data}{shipment}{shipping_class_id},
                channel_id          => $handler->{data}{order}{channel_id},
                shipment_obj        => $shipment_obj,
            );

            $handler->{data}{new_shipping} = calc_shipping_charges($handler->{dbh}, \%shipping_param);

            # round it for display
            $handler->{data}{new_shipping_charge} = _d2($handler->{data}{new_shipping}{charge});

            # add to new total
            $handler->{data}{new_total} += $handler->{data}{new_shipping_charge};
        } catch {
            xt_warn( "Error Calculating Shipping Charge:<br>" . $_ );
            if ( $handler->{data}{restrictions}{restrict} ) {
                xt_warn( "There are Shipping Restrictions on the Shipment Items these may or may not be restricting the Shipping Options that can be used." );
            }
            # set the Shipping Charge to being 'Unknown'
            $handler->{data}{new_shipping_charge}   = 'Unknown';
            $handler->{data}{dont_show_email}       = 1;
        };

        # work out difference between current and new total
        $handler->{data}{difference}    = $handler->{data}{new_total} - $handler->{data}{current_total};

        # tidy up values for display
        $handler->{data}{new_total}     = _d2($handler->{data}{new_total});
        $handler->{data}{current_total} = _d2($handler->{data}{current_total});
        $handler->{data}{difference}    = _d2($handler->{data}{difference});

        # use a standard placeholder for the Order Number
        $handler->{data}{order_number}  = ( $order_obj ? $order_obj->order_nr : '' );

        # get correct email template
        if ($handler->{data}{action} eq 'Check'){
            $handler->{data}{email_info} = get_and_parse_correspondence_template(
                $handler->{schema},
                $CORRESPONDENCE_TEMPLATES__REQUEST_PRICE_CHANGE_CONFIRMATION__1,
                {
                    channel     => $shipment_obj->get_channel,
                    data        => $handler->{data},
                    base_rec    => $shipment_obj,
                },
            );
        }
        else {
            # BUG: http://jira4.nap/browse/FLEX-604
            $handler->{data}{email_info} = get_email_template( $handler->{dbh}, $CORRESPONDENCE_TEMPLATES__CONFIRM_PRICE_CHANGE__1, $handler->{data} );
        }
    }
    # no shipment selected
    else {
        $handler->{data}{subsubsection} = 'Select Shipment';
        $handler->{data}{shipments}     = get_order_shipment_info( $handler->{dbh}, $handler->{data}{order_id} );
    }


    return $handler->process_template( undef );
}

### Subroutine : _get_country_list              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _get_country_list {

    my ($dbh) = @_;


    my $qry  = "SELECT country FROM country";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $$row{country} } = $$row{country};
    }

    return \%data;
}

### Subroutine : _get_country_id                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _get_country_id {

    my ($dbh, $country) = @_;

    my $country_id = "";

    my $qry  = "SELECT id FROM country WHERE country = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($country);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $country_id = $row->[0];
    }

    return $country_id;
}

### Subroutine : _d2                            ###
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
