package XT::Service::Order::AuthorisePayment;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Class::Std;
use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dump qw(pp);
use Readonly;
use XTracker::Logfile qw( xt_logger );
use XT::Domain::Order;
use XT::Domain::Payment;
use XTracker::Error;
use XTracker::Database qw( get_database_handle );
use XTracker::Database::Order qw( get_order_total_charge );
use XTracker::Config::Local qw( config_var );
use Email::Valid;

Readonly my $CREDIT_CARD_START_EXPIRE_YEAR_SPAN => 10;
Readonly my @CREDIT_CARD_TYPES => (
    { name => 'Visa',           value => 'VISA' },
    { name => 'Electron',       value => 'ELECTRON' },
    { name => 'Amex',           value => 'AMEX' },
    { name => 'Mastercard',     value => 'MASTERCARD' },
    { name => 'Delta',          value => 'DELTA' },
    { name => 'Maestro',        value => 'MAESTRO' },
    { name => 'JCB',            value => 'JCB' },
);
Readonly my %CHANNEL_MAPPING => (
    'NET-A-PORTER.COM'  => 'PaymentService_NAP',
    'theOutnet.com'    => 'PaymentService_OUTNET',
    'MRPORTER.COM'      => 'PaymentService_MRP',
);

use base qw/ XT::Service /;

{

    my %payment_domain_of  :ATTR( get => 'payment_domain',  set => 'payment_domain' );
    my %order_domain_of  :ATTR( get => 'order_domain',      set => 'order_domain' );



    sub START {
        my($self) = @_;
        my $schema = $self->get_schema;

        $self->set_payment_domain(
            XT::Domain::Payment->new()
        );

        $self->set_order_domain(
            XT::Domain::Order->new({ schema => $schema })
        );
    }

    sub process {
        my($self) = @_;
        my $handler = $self->get_handler();
        my $schema = $handler->{schema};

        # create objects that provide access to the tiers we want
        my $payment = $self->get_payment_domain;

        # get and split the url
        my @url_levels  = split /\//, $handler->{data}{uri};

        # info for the template
        $handler->{data}{section}       = $url_levels[1];
        $handler->{data}{subsection}    = $url_levels[2];
        $handler->{data}{subsubsection} = 'Pre-Authorise Payment';
        $handler->{data}{sidenav}       = [];

        # check for orders_id in url
        if ( defined $handler->{param_of}->{orders_id} ) {

            # pass form params to template data ref
            $handler->{data}{params}    = $handler->{param_of};
            $handler->{data}{orders_id} = $handler->{param_of}->{orders_id};

            # get order data required
            $handler->{data}{order}             = $schema->resultset('Public::Orders')->find( $handler->{data}{orders_id} );
            $handler->{data}{customer_rec}      = $handler->{data}{order}->customer;
            $handler->{data}{sales_channel}     = $handler->{data}{order}->channel->name;
            $handler->{data}{payment_value}     = get_order_total_charge( $schema->storage->dbh, $handler->{param_of}->{orders_id} );

            # add back link to left nav
            push( @{ $handler->{data}{sidenav}[ 0 ]{'None'} }, { title => 'Back', url => "/$url_levels[1]/$url_levels[2]/OrderView?order_id=$handler->{data}{orders_id}" } );
        }
        # check for renumeration_id in url
        elsif ( defined $handler->{param_of}->{renumeration_id} ) {

            my $renumeration = $schema->resultset('Public::Renumeration')->find(
                $handler->{param_of}->{renumeration_id} );

            $handler->{data}{renumeration_id} = $renumeration->id;
            $handler->{data}{customer_rec}    = $renumeration->shipment->order->customer;

        }
        else {

            xt_warn( 'Missing an order or remuneration to do a pre-auth for (did you access this page by typing the URL)' );
            return;

        }

        unless ( $handler->{data}{customer_rec}->account_urn ) {

            xt_warn( 'This customer cannot interact with the Payment Service, as they do not have an account in Seaview' );
            return;

        }

        # start/expiry date drop downs and card types
        $self->_make_start_date_options($handler);
        $self->_make_expiry_date_options($handler);
        $handler->{data}{card_types} = \@CREDIT_CARD_TYPES;

        my $payment_form = $payment->payment_form(
            handler  => $handler,
            customer => $handler->{data}{customer_rec},
        );

        if ( $payment_form->is_redirect_request ) {

            if ( $payment_form->payment_success ) {

                $self->_authorise_payment( $handler, $payment_form->current_payment_session_id );
            } else {

                xt_warn( "Payment service error: $_" )
                    foreach @{ $payment_form->payment_errors };
            }

        } else {

            unless ( $payment_form->current_payment_session_id ) {

                xt_warn( 'There was a problem with the Payment Service, please try refreshing the page' );

            }

            if (
                defined $handler->{param_of}->{action} &&
                $handler->{param_of}->{action} =~ m/^cancel$/i
            ) {
            # Take care of the cancellation form.

                # cancel a Pre-Auth
                my $response    = $handler->{data}{order}->cancel_payment_preauth( {
                                                    context => 'Pre-Authorise Payment Page',
                                                    operator_id => $handler->operator_id,
                                                } );
                if ( $response ) {
                    if ( $response->{success} ) {
                        xt_success("Pre-Auth Cancelled");
                    }
                    else {
                        xt_warn( "There was a problem whilst trying to Cancel the Pre-Auth:<br/>" . $response->{message} );
                    }
                }

            }

        }

        # get the payment pre auth details
        if ( $handler->{data}{orders_id} ) {

            my $ord_payment = ( $handler->{data}{order} ? $handler->{data}{order}->discard_changes->payments->first : undef );
            if ( $ord_payment ) {
                $handler->{data}{order_payment}     = $ord_payment;
                $handler->{data}{payment_cancel_log}= [ $ord_payment->log_payment_preauth_cancellations
                                                                        ->search( {}, { order_by => 'id' } )->all ];
                $handler->{data}{payment_replacement_cancel_log} = [ $handler->{data}{order}->get_log_replaced_payment_preauth_cancellation()->all ];
                $handler->{data}{payment_info}      = $payment->getinfo_payment( { reference => $ord_payment->preauth_ref } );

            }
        }

        return;

    }

    sub _make_start_date_options {
        my($self,$handler) = @_;

        $handler->{data}{start_date_months} = $self->_make_month_options;

        my $yr_end = (localtime)[5];
        my $yr_start = (localtime)[5]-$CREDIT_CARD_START_EXPIRE_YEAR_SPAN;

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
        my($self,$handler) = @_;

        $handler->{data}{expiry_date_months} = $self->_make_month_options;

        my $yr_start = (localtime)[5];
        my $yr_end = (localtime)[5]+$CREDIT_CARD_START_EXPIRE_YEAR_SPAN;

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

    sub _authorise_payment {
        my( $self, $handler, $payment_session_id ) = @_;

        my $result          = undef;
        my $order_domain    = $self->get_order_domain;
        my $order_id        = $handler->{param_of}{orders_id};
        my $config_section  = $CHANNEL_MAPPING{ $handler->{data}{sales_channel} };

        my $init_ref = $self->_call_init(
            $config_section, $handler->{data}, $payment_session_id );

        return if (not defined $init_ref);

        my $preauth_ref = $self->_call_preauth( {
            init_ref           => $init_ref,
            data               => $handler->{data},
            payment_session_id => $payment_session_id,
            operator_id        => $handler->operator_id,
        } );

        return if (not defined $preauth_ref);

        xt_success( 'Pre-Authorisation successful' );

        return 1;
    }

    sub _call_init {
        my ( $self, $config_section, $data, $payment_session_id ) = @_;

        my $result       = undef;
        my $return_code  = undef;
        my $order_domain = $self->get_order_domain;

        my $payload = {
            address1            => $data->{order}->order_address->address_line_1,
            address2            => $data->{order}->order_address->address_line_2,
            address3            => $data->{order}->order_address->towncity,
            billingCountry      => $data->{order}->order_address->country_table->code,
            channel             => config_var($config_section, 'merchant_channel'),
            coinAmount          => $data->{payment_value},
            currency            => $data->{order}->currency->currency,
            distributionCentre  => config_var($config_section, 'dc_channel'),
            firstName           => $data->{order}->order_address->first_name,
            isPreOrder          => 0,
            lastName            => $data->{order}->order_address->last_name,
            merchantUrl         => config_var($config_section, 'merchant_url'),
            paymentMethod       => 'CREDITCARD',
            paymentSessionId    => $payment_session_id,
            postcode            => $data->{order}->order_address->postcode,
            title               => '',
        };

        # convert remove decimal place
        if (defined $payload->{coinAmount} and $payload->{coinAmount} > 0) {
            $payload->{coinAmount}
                = $self->get_payment_domain->shift_dp( $payload->{coinAmount} );
        }

        # Set the email parameter if we've been given a valid email address.
        $payload->{email} = $data->{order}->customer->email
            if Email::Valid->address( $data->{order}->customer->email );

        $result = $self->get_payment_domain->init_with_payment_session( $payload );

        $return_code = $result->{returnCodeResult};

        # FIXME: hardcoding is bad I know
        if (defined $return_code) {
            # success
            if ($return_code == 7 or $return_code == 8) {

                # get init ref from response
                my $initRef = defined $result->{reference}
                                ? ref($result->{reference})
                                    ? $result->{reference}->numify
                                    : $result->{reference}
                                : undef;
                return $initRef;
            }
            # missing info
            elsif ($return_code == 3) {

                xt_warn( "Mandatory information missing, please check the details entered and try again.<br />Init Status: '"
                    ."$result->{extraReason}'" );
            }
            else {
                xt_warn( "The payment service was unable to process the transaction, please try again or if the problem persists please contact the IT Department.<br />Init Status: '"
                    ."$result->{extraReason}'" );
            }
        }
        else {
            xt_warn( "The payment service was unable to process the transaction, please try again or if the problem persists please contact the IT Department.<br />Init Status: message did not include return code" );
        }

        # return cos it went horribly wrong
        return;
    }

    sub _call_preauth {
        my ( $self, $args ) = @_;

        my $init_ref           = $args->{init_ref};
        my $data               = $args->{data};
        my $payment_session_id = $args->{payment_session_id};
        my $operator_id        = $args->{operator_id};

        my $result = undef;
        my $order_domain = $self->get_order_domain;
        my $return_code = undef;

        my $payload = {
            paymentSessionId    => $payment_session_id,
            reference           => $init_ref,
            orderNumber         => $data->{order}->order_nr,
        };

        $result = $self->get_payment_domain->preauth_with_payment_session( $payload );

        $return_code = $result->{returnCodeResult};

        # FIXME: hardcoding is bad I know
        if (defined $return_code) {

            # success
            if ($return_code == 1) {

                # get preauth_ref from response
                my $preauth_ref = defined $result->{reference}
                                ? ref($result->{reference})
                                    ? $result->{reference}->numify
                                    : $result->{reference}
                                : undef;

                # get payment info from service
                my $payment_info = $self->get_payment_domain->getinfo_payment({ reference => $preauth_ref });

                # need to make sure the Payment Method on the 'orders.payment'
                # record is a 'Credit Card' as only Credit Card payments can be
                # created via this Class and not Third Party methods such as PayPal
                my $credit_card_method = $self->get_schema->resultset('Orders::PaymentMethod')->find( {
                    payment_method => 'Credit Card',
                } );

                # save psp ref and preauth ref to the order record
                $order_domain->update_payment( $data->{order}->id, {
                    psp_ref           => $payment_info->{providerReference},
                    preauth_ref       => $preauth_ref,
                    valid             => 1,
                    payment_method_id => $credit_card_method->id,
                } );

                # if the Shipment is on Hold for Third Party PSP Reasons this will Release it
                $order_domain->update_shipment_status_based_on_third_party_psp_payment_status(
                    $data->{order}->id,
                    $operator_id,
                );

                return $preauth_ref;
            }
            # bank reject
            elsif ($return_code == 2) {
                xt_warn( "The transaction has been rejected by the issuing bank, please retry or use another credit card if possible.<br />Preauth Status: '"
                    ."$result->{extraReason}'" );
            }
            # missing info
            elsif ($return_code == 3) {
                xt_warn( "Mandatory information missing, please check the details entered and try again .<br />Preauth Status: '"
                    ."$result->{extraReason}'" );
            }
            else {
                xt_warn( "The payment service was unable to process the transaction, please try again or if the problem persists please contact the IT Department.<br />Preauth Status: '"
                    ."$result->{extraReason}'" );
            }
        }
        else {
            xt_warn( "The payment service was unable to process the transaction, please try again or if the problem persists please contact the IT Department.<br />Preauth Status: message did not include return code" );
        }

        return;
    }
}

1;
