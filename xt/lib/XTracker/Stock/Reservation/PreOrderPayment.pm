package XTracker::Stock::Reservation::PreOrderPayment;

use strict;
use warnings;

use XTracker::Logfile                   qw( xt_logger );
use XTracker::Navigation                qw( build_sidenav );
use XTracker::Error;
use XTracker::Utilities                 qw( format_currency_2dp );
use XTracker::Config::Local;

use XTracker::Constants::FromDB         qw( :variant_type :reservation_status :pre_order_status :pre_order_item_status :reservation_source );
use XTracker::Constants::Reservations   qw( :reservation_messages :reservation_types :pre_order_packaging_types );
use XTracker::Constants::Payment        qw( :payment_card_types );
use XTracker::Constants::Reservations   qw( :reservation_messages );
use XTracker::Database::Utilities;

use Try::Tiny;

use XT::Domain::Payment;
use XTracker::Stock::Reservation::PreOrderPaymentWS;

my $logger = xt_logger(__PACKAGE__);

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{section}            = 'Reservation';
    $handler->{data}{subsection}         = 'Customer';
    $handler->{data}{subsubsection}      = 'Pre Order Payment';
    $handler->{data}{content}            = 'stocktracker/reservation/pre_order_payment.tt';
    $handler->{data}{js}                 = ['/javascript/xui.js', '/javascript/preorder/preorder-payment.js'];
    $handler->{data}{css}                = '/css/preorder/preorder-payment.css';
    $handler->{data}{sidenav}            = build_sidenav({
        navtype    => 'reservations',
        res_filter => 'Personal'
    });

    my $customer   = undef;
    my $channel    = undef;
    my $pre_order  = undef;

    # Get customer data
    if ( is_valid_database_id( $handler->{param_of}{pre_order_id} ) ) {
        $logger->debug('A pre_order_id was provided so lets use that');
        $handler->{data}{pre_order} = $handler->schema->resultset('Public::PreOrder')->find($handler->{param_of}{pre_order_id});
        $pre_order                  = $handler->{data}{pre_order};

        if ($pre_order) {
            $handler->{data}{sales_channel} = $pre_order->customer->channel->name;
            $handler->{data}{customer}      = $pre_order->customer;
            $customer                       = $pre_order->customer;
            $channel                        = $pre_order->customer->channel;
            $handler->{data}{discount_on}   = $channel->can_apply_pre_order_discount;
        }
        else {
            xt_warn($RESERVATION_MESSAGE__PRE_ORDER_NOT_FOUND);
            return $handler->redirect_to('/StockControl/Reservation/Customer');
        };
    }
    else {
        xt_warn($RESERVATION_MESSAGE__PRE_ORDER_NOT_FOUND);
        return $handler->redirect_to('/StockControl/Reservation/Customer');
    }

    # start/expiry date drop downs and card types
    _make_start_date_options($handler);
    _make_expiry_date_options($handler);

    $handler->{data}{payment_card_types} = $PAYMENT_CARD_TYPES_ARRAY;
    $handler->{data}{payment_due}        = format_currency_2dp($pre_order->total_value);

    try {

        $handler->{data}{savedcards} = $handler->{data}{customer}->get_saved_cards( {
            operator  => $handler->operator,
            cardToken => $handler->{data}{customer}->get_or_create_card_token,
        } );

    }

    catch {
        my $error = $_;

        xt_warn( "Unable to fetch a list of Saved Cards for this Customer: $error" );

    };

    my $payment      = XT::Domain::Payment->new;
    my $payment_form = $payment->payment_form(
        handler  => $handler,
        customer => $customer,
    );

    if ( $payment_form->is_redirect_request ) {

        if ( $payment_form->payment_success ) {

            my $process_payment = XTracker::Stock::Reservation::PreOrderPaymentWS->new(
                domain_payment      => $payment,
                message_factory     => $handler->msg_factory,
                operator            => $handler->operator,
                payment_session_id  => $payment_form->current_payment_session_id,
                pre_order           => $handler->{data}{pre_order},
                schema              => $handler->schema,
            );

            my $process_payment_result;
            try {
                $process_payment_result = $process_payment->process;
            } catch {
                my $error = $_;
                xt_warn( "Payment Service Error: $error" );
            };

            if ( $process_payment_result ) {

                xt_success( $RESERVATION_MESSAGE__PRE_ORDER_SUCCESS_FOR_ALL );
                return $handler->redirect_to( '/StockControl/Reservation/PreOrder/Complete?pre_order_id=' . $pre_order->id );

            }

        } else {

            my @error =   ref($payment_form->payment_errors) eq 'ARRAY' && @{ $payment_form->payment_errors } ? @{ $payment_form->payment_errors } : "Payment was unsuccessful" ;
            xt_warn( "Payment service error: $_" )
                foreach @error;


        }

    }

    return $handler->process_template;

}


sub _make_start_date_options {
    my($handler) = @_;

    $handler->{data}{start_date_months} = __PACKAGE__->_make_month_options;

    my $yr_end = (localtime)[5];
    my $yr_start = (localtime)[5]-10;

    my @years;
    push @years, {
        name => 'n/a',
        value => '',
    };
    foreach my $year ( $yr_start..$yr_end ) {
        my $len = 2;
        $year =~ s/^\d+(\d\d)$/$1/;
        my $str = sprintf "%0${len}d", $year;

        push @years, {
            name    => $str,
            value   => $str,
        },
    }

    $handler->{data}{start_date_years} = \@years;
    return;
}

sub _make_expiry_date_options {
    my($handler) = @_;

    $handler->{data}{expiry_date_months} = __PACKAGE__->_make_month_options;

    my $yr_start = (localtime)[5];
    my $yr_end = (localtime)[5]+10;

    my @years;
    push @years, {
        name => 'n/a',
        value => '',
    };
    foreach my $year ( $yr_start..$yr_end ) {
        my $len = 2;
        $year =~ s/^\d+(\d\d)$/$1/;
        my $str = sprintf "%0${len}d", $year;

        push @years, {
            name    => $str,
            value   => $str,
        },
    }

    $handler->{data}{expiry_date_years} = \@years;

    return;
}



sub _make_month_options {
    my($self) = @_;

    my @months;
    push @months, {
        name => 'n/a',
        value => '',
    };
    foreach my $month ( 1..12 ) {
        my $len = 2;
        my $str = sprintf "%0${len}d", $month;;

        push @months, {
            name    => $str,
            value   => $str,
        },
    }

    return \@months;
}

1;
