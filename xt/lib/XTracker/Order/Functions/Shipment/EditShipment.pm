package XTracker::Order::Functions::Shipment::EditShipment;

use strict;
use warnings;

use Perl6::Export::Attrs;
use Try::Tiny;
use JSON;

use XTracker::Handler;
use XTracker::Config::Local         qw( :carrier_automation );

use XTracker::Database::Shipment    qw(
    get_address_shipping_charges
    :DEFAULT :carrier_automation);

use XTracker::Logfile qw( xt_logger );
use XTracker::Database::Logging     qw( :carrier_automation );
use XTracker::Database::Order;
use XTracker::Database::Address;
use XTracker::DHL::Manifest         qw( get_manifest_list );

use XTracker::Utilities qw( parse_url number_in_list );
use XTracker::Constants::FromDB qw( :department :shipment_type :shipment_item_status :shipment_status );
use XT::Net::WebsiteAPI::Client::NominatedDay;
use XT::Net::WebsiteAPI::Response::AvailableDate;
use XT::Data::DateStamp;

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Edit Shipment';
    $handler->{data}{short_url}     = $short_url;
    $handler->{data}{content}       = 'ordertracker/shared/editshipment.tt';

    # get order id and shipment id from url
    $handler->{data}{order_id}      = $handler->{request}->param('order_id');
    $handler->{data}{shipment_id}   = $handler->{request}->param('shipment_id');

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "$short_url/OrderView?order_id=$handler->{data}{order_id}" } );

    # get order info from db
    $handler->{data}{order}             = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{sales_channel}     = $handler->{data}{order}{sales_channel};
    $handler->{data}{pod}               = check_order_payment( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{invoice_address}   = get_address_info( $handler->{schema}, $handler->{data}{order}{invoice_address_id} );


    my $channel = $handler->{schema}->find(
        Channel => $handler->{data}{order}{channel_id},
    );

    # shipment id selected
    if ( $handler->{data}{shipment_id} ) {
        # get the Customer record
        my $customer_id = $handler->{data}{order}{customer_id};
        $handler->{data}{customer} = $handler->schema->resultset('Public::Customer')->find( $customer_id );

        # flag to indicate if user in correct department to edit certain shipment details
        $handler->{data}{auth_department} = 0;
        $handler->{data}{show_autoable}   = 0;
        $handler->{data}{can_edit_autoable}= 0;

        $handler->{data}{show_autoable} = 1;
        # test to see if this shipment can be automated
        $handler->{data}{can_edit_autoable} = autoable( $handler->{schema}, {
                                                    shipment_id => $handler->{data}{shipment_id},
                                                    mode        => 'isit',
                                                    operator_id => $handler->operator_id,
                                                  } );
        $handler->{data}{rtcb_change_log}   = get_log_shipment_rtcb( $handler->{dbh}, $handler->{data}{shipment_id} );

        # distribution, customer care managers and shipping dept authorised to make changes
        $handler->{data}{auth_department} = 1 if
        (
            $handler->{data}{department_id} == $DEPARTMENT__DISTRIBUTION_MANAGEMENT ||
            $handler->{data}{department_id} == $DEPARTMENT__SHIPPING                ||
            $handler->{data}{department_id} == $DEPARTMENT__SHIPPING_MANAGER        ||
            $handler->{data}{department_id} == $DEPARTMENT__CUSTOMER_CARE_MANAGER
        );

        # get shipment data from db
        my $shipment = $handler->{schema}->resultset('Public::Shipment')->find( $handler->{data}{shipment_id} );
        $handler->{data}->{shipment_type_name} = $shipment->shipment_type->type;
        $handler->{data}{shipment}         = get_shipment_info     ( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{shipment_address} = get_address_info      ( $handler->{schema}, $handler->{data}{shipment}{shipment_address_id} );
        $handler->{data}{shipment_item}    = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{paperwork}        = get_shipment_documents( $handler->{dbh}, $handler->{data}{shipment_id} );


        my $nominated_day_shipping_options = get_nominated_day_shipping_options(
            $handler->{dbh},
            $channel,
            $handler->{data},
            $handler->{data}{shipment},
            $handler->{data}{shipment_item},
            $handler->{data}{shipment_address},
            $shipment,
        );
        @{ $handler->{data} }{keys %$nominated_day_shipping_options}
            = values %$nominated_day_shipping_options;


        # If shipment has been Dispatched or shipment is on a Manifest then don't let the Carrier Automation field
        # be Editable, but only check this if the edit feature hasn't been turned off already.
        if ( $handler->{data}{can_edit_autoable} ) {
            my $manifest    = get_manifest_list( $handler->{dbh}, { type => "shipment", shipment_id => $handler->{data}{shipment_id} } );
            if ( number_in_list($handler->{data}{shipment}{shipment_status_id},
                                $SHIPMENT_STATUS__DISPATCHED,
                                $SHIPMENT_STATUS__CANCELLED,
                                $SHIPMENT_STATUS__RETURN_HOLD,
                                $SHIPMENT_STATUS__EXCHANGE_HOLD,
                                $SHIPMENT_STATUS__LOST,
                                $SHIPMENT_STATUS__DDU_HOLD,
                                $SHIPMENT_STATUS__RECEIVED,
                                $SHIPMENT_STATUS__PRE_DASH_ORDER_HOLD,
                            )
                     || keys %{ $manifest } ) {
                $handler->{data}{can_edit_autoable} = 0;
            }
        }

        # if the rtcb field is editable but you are not in the
        # correct department then you can't edit it
        if ( $handler->{data}{can_edit_autoable} ) {
            if ( $handler->department_id != $DEPARTMENT__SHIPPING
              && $handler->department_id != $DEPARTMENT__SHIPPING_MANAGER ) {
                $handler->{data}{can_edit_autoable} = 0;        # you can't edit the field
            }
        }

        # flag to indicate if shipping input form has printed - this is a cut off for editing addresses etc..
        $handler->{data}{shipping_input} = 0;

        foreach my $doc_id ( keys %{ $handler->{data}{paperwork} } ) {
            if ($handler->{data}{paperwork}{$doc_id}{document} eq "Shipping Input Form"){
                $handler->{data}{shipping_input} = $doc_id;
            }
        }
    }
    # get list of shipments to select from
    else {
        $handler->{data}{shipments}     = get_order_shipment_info( $handler->{dbh}, $handler->{data}{order_id} );
    }

    return $handler->process_template( undef );
}

sub get_nominated_day_shipping_options : Export() {
    my ($dbh, $channel, $data, $shipment, $shipment_item, $shipment_address, $shipment_obj) = @_;

    ### Determine if the Shipping Options can be changed, and to what
    my $shipping_option = get_shipping_options($shipment, $shipment_item);

    # Set shipment->available_nominated_delivery_dates to either
    # the available dates (if the delivery date can be changed),
    # or the current delivery date (if there is one)
    try {
        $shipment->{available_nominated_delivery_dates}
            = get_available_or_current_nominated_delivery_dates(
                $channel,
                $shipment,
                $shipment_address,
                $shipping_option->{can_change_nominated_day_delivery_date},
            );
    }
    catch {
        chomp;
        $shipment->{website_api_client_error} = $_;
    };

    my $exclude_nominated_day
        = ! $shipping_option->{can_change_shipping_charge_to_nominated_day};
    my %shipping_charges = get_address_shipping_charges(
        $dbh,
        $channel->id,
        {
            country  => $shipment_address->{country},
            postcode => $shipment_address->{postcode},
            state    => $shipment_address->{county},
        },
        {
            exclude_nominated_day   => $exclude_nominated_day,
            always_keep_sku         => $shipment->{shipping_charge_sku},
            (
                $shipment_obj
                ? ( exclude_for_shipping_attributes => $shipment_obj->get_item_shipping_attributes )
                : ()
            ),
        },
    );

    my $sku_available_nominated_delivery_dates
        = get_sku_current_and_available_nominated_delivery_dates(
            $channel,
            \%shipping_charges,
            $shipment_address,
            # For current shipping_charge
            $shipment->{shipping_charge_sku},
            $shipment->{available_nominated_delivery_dates},
        );

    return {
        %$shipping_option,
        shipping_charges                            => \%shipping_charges,
        shipping_charges_json                       => json()->encode(\%shipping_charges),
        sku_available_nominated_delivery_dates_json => json_from_sku_available_dates(
            $sku_available_nominated_delivery_dates,
        ),
    };
}

my $json_parser_singleton;
sub json : Export() {
    return $json_parser_singleton ||= JSON->new
        ->utf8
        ->convert_blessed(1)
        ->canonical(1)
        ->pretty;
}

sub json_from_sku_available_dates : Export() {
    my ($sku_available_dates) = @_;

    return json()->encode(
        {
            map {
                my $available_dates = $sku_available_dates->{$_} || [];
                $_ => [ map { $_->as_data } @$available_dates ],
            }
            keys %$sku_available_dates
        },
    );
}

=head2 get_shipping_options($shipment, $id_shipment_item) : $shipment_option

Return hash ref with keys:

  selected
  picked
  packed
  can_change_shipping_options
  can_change_shipping_charge_to_nominated_day
  can_change_nominated_day_delivery_date

=cut

sub get_shipping_options : Export() {
    my ($shipment, $id_shipment_item) = @_;

    my $shipment_option = get_shipment_stage($id_shipment_item);
    my $is_shipment_selected_yet = is_shipment_selected_yet( $shipment_option );

    $shipment_option->{can_change_shipping_options}
        = can_change_shipping_options($shipment);

    $shipment_option->{can_change_shipping_charge_to_nominated_day}
        = !$is_shipment_selected_yet;

    # The user can edit the delivery date if:
    $shipment_option->{can_change_nominated_day_delivery_date}
        = $shipment->{nominated_delivery_date} # there is one
            && !$is_shipment_selected_yet;     # the shipment isn't selected yet

    return $shipment_option;
}


=head2 get_shipment_stage( $id_shipment_item) : %$shipment_stage

Return hash with (keys: "selected", "picked", "packed"; values;
boolean) given all shipment_items in $id_shipment_item (keys:
shipment_item_id; values: shipment_item hashref).

=cut

sub get_shipment_stage : Export {
    my ($id_shipment_item) = @_;
    # flags to indicate what stage shipment is at
    my $data = {
        selected => 0,
        picked   => 0,
        packed   => 0,
    };

    for my $shipment_item ( values %$id_shipment_item ) {
        if (number_in_list($shipment_item->{shipment_item_status_id},
                           $SHIPMENT_ITEM_STATUS__SELECTED,
                           $SHIPMENT_ITEM_STATUS__PICKED,
                           $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                           $SHIPMENT_ITEM_STATUS__PACKED,
                       ) ) {
            $data->{selected} = 1;
        }
        if (number_in_list($shipment_item->{shipment_item_status_id},
                           $SHIPMENT_ITEM_STATUS__PICKED,
                           $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                           $SHIPMENT_ITEM_STATUS__PACKED,
                           $SHIPMENT_ITEM_STATUS__DISPATCHED,
                           $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                           $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                           $SHIPMENT_ITEM_STATUS__RETURNED,
                       ) ) {
            $data->{picked} = 1;
        }
        if (number_in_list($shipment_item->{shipment_item_status_id},
                           $SHIPMENT_ITEM_STATUS__PACKED,
                           $SHIPMENT_ITEM_STATUS__DISPATCHED,
                           $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                           $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                           $SHIPMENT_ITEM_STATUS__RETURNED,
                       ) ) {
            $data->{packed} = 1;
        }
    }

    return $data;
}

=head2 is_shipment_selected_yet($shipment_stage) : 0|1

Return whether the "selected", "picked", "packed" keys in
$shipment_stage indicate the Shipment has been selected or not.

=cut

sub is_shipment_selected_yet : Export {
    my ($shipment_stage) = @_;
    for my $what (qw/ selected picked packed /) {
        return 1 if $shipment_stage->{$what};
    }
    return 0;
}

sub can_change_shipping_options {
    my ($shipment) = @_;
    # Shipment isn't CANCELLED or DISPATCHED or RECEIVED or LOST

    return number_in_list(
        $shipment->{shipment_status_id},
        $SHIPMENT_STATUS__FINANCE_HOLD,
        $SHIPMENT_STATUS__PROCESSING,
        $SHIPMENT_STATUS__HOLD,
        $SHIPMENT_STATUS__RETURN_HOLD,
        $SHIPMENT_STATUS__EXCHANGE_HOLD,
        $SHIPMENT_STATUS__DDU_HOLD,
        $SHIPMENT_STATUS__PRE_DASH_ORDER_HOLD,
    )
    # and
    &&
    # The address label isn't printed yet
    # or it's Premier, which doesn't have a printed label
    (
           $shipment->{outward_airway_bill} eq 'none'
        || $shipment->{shipment_type_id} == $SHIPMENT_TYPE__PREMIER
    );
}

sub get_available_or_current_nominated_delivery_dates {
    my ($channel, $shipment_info, $shipment_address, $can_change_nominated_day_delivery_date) = @_;

    my $nominated_delivery_date = $shipment_info->{nominated_delivery_date};
    if ($can_change_nominated_day_delivery_date) {
        return fetch_available_nominated_delivery_dates_from_website({
            channel                 => $channel,
            sku                     => $shipment_info->{shipping_charge_sku},
            country                 => $shipment_address->{country},
            county                  => $shipment_address->{county},
            postcode                => $shipment_address->{postcode},
            nominated_delivery_date => $nominated_delivery_date,
        });
    }

    # Can't change the delivery date, so return the current delivery
    # date only, if there is one
    $nominated_delivery_date or return undef;

    return [
        XT::Net::WebsiteAPI::Response::AvailableDate->new({
            delivery_date => XT::Data::DateStamp->from_datetime(
                $nominated_delivery_date,
            ),
        })
    ];
}

sub fetch_available_nominated_delivery_dates_from_website : Export {
    my ($args) = @_;
    my $client = XT::Net::WebsiteAPI::Client::NominatedDay->new({
        channel_row => $args->{channel},
    });
    my $schema = $args->{channel}->result_source->schema;

    my $available_dates = eval {
        $client->available_dates( available_dates_args($schema, $args) );
    };
    if(my $e = $@) {
        chomp($e);
        xt_logger->error("Could not determine available Nominated Day delivery dates: $e");
        die "Couldn't determine available delivery days, please retry later if you need to change it. Please contact ServiceDesk if this persists, or is urgent.\n";
    }

    $args->{nominated_delivery_date} or return $available_dates;
    return ensure_current_nominated_delivery_date_is_present(
        $available_dates,
        $args->{nominated_delivery_date}
    );
}

=head2 get_sku_current_and_available_nominated_delivery_dates( ... ) : %$sku_available_nominated_delivery_dates

For the param docs, refer to the code.

Return hash ref with (keys: sku; values: arrayref with AvailableDate
objects) for all Shipping Charges in $id_shipping_charge that are for
Nominated Day.

The Available Delivery Days are fetched from the Website API.

If the $current_sku is for Nominated Day and it already has a list of
$current_available_delivery_dates, those are always used for that
sku. (If that is the case, the list of delivery dates should normally
include the current nominated_delivery_date for the Shipment, so that
the user can always select the current value).

=cut

sub get_sku_current_and_available_nominated_delivery_dates : Export() {
    my (
        $channel,                          # Channel row object
        $id_shipping_charge,               # Hash ref with (keys: id; values: shipping_charge hashref)
                                           # from get_address_shipping_charges
        $shipment_address,                 # From get_address_info()
        $current_sku,                      # Shipping SKU of the current Shipment
        $current_available_delivery_dates, # Array ref with WebsiteAPI::Response::AvailableDate
                                           # objects for the current SKU
    ) = @_;
    $current_available_delivery_dates ||= [ ];

    my $nominated_day_skus = [
        map  { $_->{sku} }
        grep { $_->{is_nominated_day} }
        values %$id_shipping_charge,
    ];

    # If this eval fails, the available days call for the current
    # SKU also failed, and the user will see that error message
    my $sku_available_delivery_dates = eval {
        get_sku_available_nominated_delivery_dates(
            $channel,
            $nominated_day_skus,
            $shipment_address,
            undef, # Don't include an already chosen date, since these
                   # are new shipping_options
        );
    } || { };

    # The current shipping charge dates are always selectable,
    # even if we can't pick another Nominated Day SKU

    # If we have current available dates, overwrite it with that,
    # because the current available dates can also include the current
    # date (even if it's not valid any more).
    # It may also contain _only_ the current date, if that's
    # appropriate.
    if(@$current_available_delivery_dates) {
        $sku_available_delivery_dates->{ $current_sku }
            = $current_available_delivery_dates;
    }

    return $sku_available_delivery_dates;
}

sub get_sku_available_nominated_delivery_dates {
    my ($channel, $skus, $shipment_address, $nominated_delivery_date) = @_;

    my %sku_available_nominated_delivery_date =
        map {
            (
                $_ => fetch_available_nominated_delivery_dates_from_website({
                    channel                 => $channel,
                    sku                     => $_,
                    country                 => $shipment_address->{country},
                    county                  => $shipment_address->{county},
                    postcode                => $shipment_address->{postcode},
                    nominated_delivery_date => $nominated_delivery_date,
                })
            )
        }
        @$skus;

    return \%sku_available_nominated_delivery_date;
}

sub available_dates_args {
    my ($schema, $args) = @_;

    my $country_code = get_country_code($schema, $args->{country});
    my $state = $country_code eq "US" ? $args->{county} : undef;

    return {
        sku      => $args->{sku},
        country  => $country_code,
        state    => $state,
        postcode => $args->{postcode},
    };
}

sub get_country_code {
    my ($schema, $country) = @_;
    my $country_rs = $schema->resultset("Public::Country");
    my $country_row = $country_rs->search({ country => $country })->first
        or die("Could not find a country code for the country ($country)\n");
    return $country_row->code;
}

sub ensure_current_nominated_delivery_date_is_present {
    my ($available_dates, $nominated_delivery_date) = @_;
    $nominated_delivery_date = XT::Data::DateStamp->from_datetime(
        $nominated_delivery_date,
    );

    my $available_date_object = {
        map { $_->delivery_date->ymd => $_ }
        @$available_dates
    };
    $available_date_object->{ "$nominated_delivery_date" }
        ||= XT::Net::WebsiteAPI::Response::AvailableDate->new({
            delivery_date => $nominated_delivery_date,
        });
    my $all_available_dates = [
        sort { $a->delivery_date->ymd cmp $b->delivery_date->ymd }
        values %$available_date_object
    ];

    return $all_available_dates;
}

1;
