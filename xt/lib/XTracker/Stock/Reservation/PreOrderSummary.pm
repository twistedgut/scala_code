package XTracker::Stock::Reservation::PreOrderSummary;

use strict;
use warnings;

use XTracker::Logfile                 qw( xt_logger );
use XTracker::Navigation              qw( build_sidenav );
use XTracker::Image;
use XTracker::Error;
use XTracker::Utilities               qw( format_currency_2dp :string );
use XTracker::Config::Local           qw( config_var has_delivery_signature_optout get_postcode_required_countries_for_preorder );

use XTracker::Database::Currency        qw( get_currency_glyph_map );

use XTracker::Constants::FromDB         qw( :pre_order_status :pre_order_item_status :department );
use XTracker::Constants::Reservations   qw( :reservation_messages :reservation_types :pre_order_packaging_types );
use XTracker::Constants::PreOrder       qw( :pre_order_operator_control :pre_order_messages );

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
    $handler->{data}{subsubsection}      = 'Pre Order Summary';
    $handler->{data}{content}            = 'stocktracker/reservation/pre_order_summary.tt';
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
    my $pre_order  = undef;

    # Is parameter supplied and a referencing a valid pre-order?
    if ( my $pre_order_id = strip($handler->{param_of}{pre_order_id}) ) {

        $logger->debug('A pre_order_id was provided so lets use that');

        my $err;
        try {
            $handler->{data}{pre_order} = $handler->schema->resultset('Public::PreOrder')->find($pre_order_id);
            $pre_order                  = $handler->{data}{pre_order};

            die "No pre-order found for pre_order_id '$pre_order_id'\n" unless $pre_order;
            $err = 0;
        }
        catch {
            $logger->warn($_);
            xt_warn($RESERVATION_MESSAGE__PRE_ORDER_NOT_FOUND);
            $err = 1;
        };
        return $handler->redirect_to('/StockControl/Reservation/Customer') if $err;
    }
    else {
        xt_warn($RESERVATION_MESSAGE__CUSTOMER_NOT_FOUND);
        return $handler->redirect_to('/StockControl/Reservation/Customer');
    }

    # Operator transfer
    if ($handler->{param_of}{new_operator_id}) {
        try {
            my $new_operator = $handler->schema->resultset('Public::Operator')->find($handler->{param_of}{new_operator_id});
            my $by_operator  = $handler->schema->resultset('Public::Operator')->find($handler->operator_id);

            if ($pre_order->transfer_to_operator($new_operator, $by_operator)) {
                xt_success(sprintf($PRE_ORDER_MESSAGE__OPERATOR_TRANSFER_SUCCESS, $new_operator->name));
            }
            else {
                xt_warn(sprintf($PRE_ORDER_MESSAGE__OPERATOR_TRANSFER_FAILURE, $new_operator->name));
            }
        }
        catch {
            $logger->warn($_);
        };
    }

    # Customer details
    $handler->{data}{customer}      = $pre_order->customer;
    $handler->{data}{sales_channel} = $pre_order->customer->channel->name;

    # Edit Pre-order Refunds
    $handler->{data}{can_edit_preorder_refund} = 1
        if ( $handler->department_id == $DEPARTMENT__FINANCE );

    # Get signature flag
    $handler->{data}{has_delivery_signature_optout} = has_delivery_signature_optout();


    # Get country list - exclusing unkwon country from the list
    $handler->{data}{countries} = [$handler->schema->resultset('Public::Country')->search({ code => { '!=' => '' } }, {order_by => 'country'})->all];
    # Get states for United States
    $handler->{data}{country_subdivision} = [$handler->schema->resultset('Public::Country')->find_by_name('United States')->country_subdivisions->all()];


    # Currency
    my $currency = $handler->schema->resultset('Public::Currency')->find($pre_order->currency->id);
    $handler->{data}{currency} = {
        id          => $currency->id,
        html_entity => get_currency_glyph_map($handler->{dbh})->{$currency->id}
    };

    # Addresses
    $handler->{data}{shipment_address}   = $pre_order->shipment_address;
    $handler->{data}{invoice_address}    = $pre_order->invoice_address;
    $handler->{data}{previous_addresses} = $pre_order->customer->get_all_used_addresses_valid_for_preorder;

    # Item variants
    $handler->{data}{variants} = $self->_variants($pre_order);

    # Add some summary data here for the moment
    $handler->{data}{item_count}    = $self->_item_count($pre_order);
    $handler->{data}{payment_info}  = $self->_payment_details($pre_order);
    $handler->{data}{order_payment} = $pre_order->pre_order_payment;

    # set-up other bits of data for the Summary page
    $handler->{data}{can_cancel_items}  = $pre_order->pre_order_items->available_to_cancel->count();
    $handler->{data}{refunds}           = $pre_order->pre_order_refunds->list_for_summary_page;
    $handler->{data}{statuses}{pre_order}       = $pre_order->pre_order_status_logs->status_log_for_summary_page;
    $handler->{data}{statuses}{pre_order_items} = $pre_order->pre_order_items->status_log_for_summary_page;

    # Drag the parameters across
    $handler->{data}{params} = $handler->{param_of};


    $handler->{data}{new_operator_list} = [$self->_get_list_of_operators_for_transfer($pre_order)];

    # For template conditionals
    $handler->{data}{origin} = 'preorder_summary';

    return $handler->process_template;
}

sub _get_list_of_operators_for_transfer {
    my ($self, $pre_order) = @_;

    my @list = ();

    return try {
        my $operator = $self->{handler}->schema->resultset('Public::Operator')->find($self->{handler}->operator_id);

        if ($operator->is_manager($PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SECTION, $PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SUBSECTION) || ($pre_order->operator_id == $self->{handler}->operator_id)) {
            return $self->{handler}->schema->resultset('Public::Operator')
                ->by_authorisation($PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SECTION, $PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SUBSECTION)
                ->search({
                    department_id => {'IN' => $PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_DEPARTMENTS},
                    disabled      => '0',
                    'me.id' => {'!=' => $pre_order->operator->id}
                }, {order_by => 'name'})
                ->all;
        }
        else {
            return @list;
        }
    }
    catch {
        $logger->warn($_);
        return @list;
    };
}

sub _item_count {
    my ($self, $pre_order) = @_;

    return $pre_order->pre_order_items->count();
}

sub _payment_details {
    my ($self, $pre_order) = @_;

    my $payment;

    if ( $pre_order->pre_order_payment ) {
        try {
            my $preauth_ref = $pre_order->pre_order_payment->preauth_ref;
            my $payment_ws  = XT::Domain::Payment->new( { acl => $self->{handler}->acl });
            $payment = $payment_ws->protected_getinfo_payment({reference => $preauth_ref});
            $payment = undef unless ( $payment_ws->pmc_protected_getinfo_payment_call_was_allowed );
        }
        catch {
            xt_warn("Couldn't get Payment Information from PSP:<br>$_");
            $logger->warn("PSP Error for Pre Order Id: " . $pre_order->id.": $_");
        };
    }
    else {
        $payment = undef;
    }
    return $payment;
}

sub _variants {

    my ($self, $pre_order) = @_;

    my %variants = ();

    # Loop through each variant
    my @items   = $pre_order->pre_order_items->order_by_sku->all;

    # capture these once for use in the loop
    my $image_host_url = $self->{handler}{data}{image_host_url};
    my $schema = $self->{handler}->schema;

    my $sort_order  = 1;
    foreach my $item (@items) {
        # use the Pre-Order Item Id because there may be in the future
        # more than one of the same Variant but on different Pre Order Items
        my $id_for_hash = $item->id;

        try {
            $logger->debug('Looking at variant #'.$item->variant_id);

            my $variant = $item->variant;

            $variants{ $id_for_hash }{images} = get_images({
                product_id     => $variant->product_id,
                live           => 1,
                schema         => $schema,
                business_id    => $pre_order->channel->business_id,
                image_host_url => $image_host_url
            });

            $variants{ $id_for_hash }{data} = {
                variant_id    => $variant->id,
                sku           => $variant->sku,
                id            => $variant->product_id,
                size          => $variant->size->size,
                designer_size => $variant->designer_size->size,
                designer      => $variant->product->designer->designer,
                name          => $variant->product->preorder_name,
            };

            $variants{ $id_for_hash }{price} = {
                unit_price  => format_currency_2dp( $item->unit_price ),
                duty        => format_currency_2dp( $item->duty ),
                tax         => format_currency_2dp( $item->tax ),
                total       => format_currency_2dp(  $item->unit_price
                                                   + $item->duty
                                                   + $item->tax ),
            };

            # Get Order id linked to PreOrder
            if( $item->is_exported ) {
                my $link_obj = $item->reservation->link_shipment_item__reservations;
                if ( $link_obj && $link_obj->count  > 0 ) {
                    $variants{ $id_for_hash }{link_order} = $link_obj->first->shipment_item->shipment->link_orders__shipment->orders_id;
                }
            }

            $variants{ $id_for_hash }{status}  = $item->pre_order_item_status->status;
            $variants{ $id_for_hash }{item}    = $item;

            $variants{ $id_for_hash }{sort_order}   = $sort_order;
            $sort_order++;
        }
        catch {
            delete($variants{ $id_for_hash });
            xt_warn(sprintf($RESERVATION_MESSAGE__CANT_FIND_VARIANT, $item->variant_id));
            $logger->warn($_);
        };
    }

    return \%variants;
}

1;
