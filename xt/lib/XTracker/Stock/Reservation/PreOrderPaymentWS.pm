package XTracker::Stock::Reservation::PreOrderPaymentWS;
use NAP::policy 'class', 'tt';

use XTracker::Config::Local;
use XTracker::Logfile                   qw( xt_logger );
use XTracker::Error;
use XTracker::Database::Reservation     qw( create_reservation );

use XTracker::Constants::Payment        qw( :psp_channel_mapping :psp_return_codes :pre_order_payment_api_messages );
use XTracker::Constants::Ajax           qw( :ajax_messages);
use XTracker::Constants::FromDB         qw( :currency :pre_order_status :pre_order_item_status );
use XTracker::Constants::Reservations   qw( :reservation_messages );

use XT::Domain::Payment;

use Plack::App::FakeApache1::Constants  qw(:common HTTP_METHOD_NOT_ALLOWED);
use Number::Format                      qw( :subs );
use JSON;

my $logger = xt_logger(__PACKAGE__);

=head1 Methods

=cut

has domain_payment => (
    is          => 'ro',
    isa         => 'XT::Domain::Payment',
    required    => 1,
);

has pre_order => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::PreOrder',
    required    => 1,
);

has payment_session_id => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

has operator => (
    is          => 'rw',
    isa         => 'XTracker::Schema::Result::Public::Operator',
    required    => 1,
);

has schema => (
    is          => 'ro',
    isa         => 'XTracker::Schema',
    required    => 1,
);

has message_factory => (
    is          => 'ro',
    isa         => 'Object',
    required    => 1,
);

has payment_currency => (
    is          => 'rw',
    isa         => 'Str',
    lazy        => 1,
    default     => sub { shift->pre_order->currency->currency },
);

has payment_amount => (
    is          => 'rw',
    isa         => 'Num',
    lazy        => 1,
    default     => sub { shift->pre_order->total_value },
);

=head2 order_payment_POST

Required Parameters:
  pre_order_id OR order_id
  payment_due
  currency

=cut

sub process {
    my $self = shift;

    my $pre_auth_db_record;
    my $payment;
    my %output;

    # capture this for passing to update methods
    my $operator_id = $self->operator->id;

    # ==================================================================
    # START

    my $pre_order                   = $self->pre_order;
    my $customer                    = $pre_order->customer;
    my $channel                     = $pre_order->channel;
    my $address                     = $pre_order->invoice_address;
    my $pre_auth_order_id           = 'pre_order_'.$pre_order->id;
    my $config_section              = $channel->business->config_section;
    my $merchant_channel            = config_var('PaymentService_'.$config_section, 'merchant_channel');
    my $merchant_url                = config_var('PaymentService_'.$config_section, 'merchant_url');
    my $dc_channel                  = config_var('PaymentService_'.$config_section, 'dc_channel');

    unless ($merchant_url && $dc_channel && $merchant_channel) {
        $logger->error('Unable to load PSP config');
        _fail( $PRE_ORDER_PAYMENT_API_MESSAGE__TECHNICAL_ERROR );
    }

    my $coinAmount;

    if (my $payment = $pre_order->get_payment) {
        $pre_auth_db_record = $payment;
        $coinAmount = $self->_calculate_coin_amount();
        %output = (
            psp_ref     => $payment->psp_ref,
            preauth_ref => $payment->preauth_ref,
            settle_ref  => $payment->settle_ref,
        )
    }
    else {
        # ==================================================================
        # Init Payment
        $logger->debug('Init payment');

        $self->schema->txn_do(sub {
            if ($pre_order->can_confirm_all_items()) {
                $logger->debug('Items can be confirmed');
                $pre_order->confirm_all_items( $operator_id );

            }
            else {
                $logger->warn( "Pre-Order Id: " . $pre_order->id . " - Items can not be confirmed'" );
                _fail(
                    $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_CONFIRM_ORDER .
                    ", there is an issue with one or more of the Items - Return to Basket"
                );
            }
        });

        try {
            # basically '123.4' should be '12340'
            $coinAmount = $self->_calculate_coin_amount();
        }
        catch {
            my $error = $_;
            $logger->error($error);
            _fail( $PRE_ORDER_PAYMENT_API_MESSAGE__TECHNICAL_ERROR );
        };

        my $init_error;
        try {

            my $psp_init_response = $self->domain_payment->init_with_payment_session( {
                address1            => $address->address_line_1,
                address2            => $address->address_line_2,
                address3            => $address->towncity,
                billingCountry      => $address->country_table->code,
                channel             => $merchant_channel,
                coinAmount          => $coinAmount,
                currency            => $self->payment_currency,
                distributionCentre  => $dc_channel,
                email               => $customer->email,
                firstName           => $address->first_name,
                isPreOrder          => 0,               # TODO investigate what this setting is
                lastName            => $address->last_name,
                merchantUrl         => $merchant_url,
                paymentMethod       => 'CREDITCARD',    # whats this? make it a constant?
                paymentSessionId    => $self->payment_session_id,
                postcode            => $address->postcode,
                title               => $customer->title,
            } );

            if (($psp_init_response->{returnCodeResult} == $PSP_RETURN_CODE__3D_SECURE_BYPASSED) || ($psp_init_response->{returnCodeResult} == $PSP_RETURN_CODE__3D_SECURE_NOT_SUPPORTED)) {
                $output{init_ref} = ref($psp_init_response->{reference})
                                        ? $psp_init_response->{reference}->numify
                                        : $psp_init_response->{reference};
            }
            elsif ($psp_init_response->{returnCodeResult} == $PSP_RETURN_CODE__MISSING_INFO) {
                $pre_order->select_all_items( $operator_id );
                $init_error = $PRE_ORDER_PAYMENT_API_MESSAGE__MISSING_DETAILS;
            }
            else {
                $logger->warn( "Unknown response for Init: $psp_init_response->{returnCodeReason} ($psp_init_response->{returnCodeResult})" );
                $pre_order->select_all_items( $operator_id );
                $init_error = $PRE_ORDER_PAYMENT_API_MESSAGE__UNKNOWN_RESPONSE;
            }
        }
        catch {
            my $error = $_;
            $logger->warn($error);
            $pre_order->select_all_items( $operator_id );
            _fail( $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_INIT );
        };

        _fail( $init_error )
            if $init_error;

        # ==================================================================
        # PreAuth Payment
        $logger->debug('PreAuth payment');

        my $preauth_error;
        try {
            my $psp_preauth_response = $self->domain_payment->preauth_with_payment_session({
                paymentSessionId    => $self->payment_session_id,
                reference           => $output{init_ref},
                orderNumber         => $pre_auth_order_id,
            });

            if ($psp_preauth_response->{returnCodeResult} == $PSP_RETURN_CODE__SUCCESS) {
                $output{preauth_ref} = ref($psp_preauth_response->{reference})
                                        ? $psp_preauth_response->{reference}->numify
                                        : $psp_preauth_response->{reference};
            }
            elsif ($psp_preauth_response->{returnCodeResult} == $PSP_RETURN_CODE__BANK_REJECT) {
                $pre_order->update_status($PRE_ORDER_STATUS__PAYMENT_DECLINED, $operator_id);
                $pre_order->select_all_items( $operator_id );
                $preauth_error = $PRE_ORDER_PAYMENT_API_MESSAGE__BANK_REJECT;
            }
            elsif ($psp_preauth_response->{returnCodeResult} == $PSP_RETURN_CODE__MISSING_INFO) {
                $pre_order->select_all_items( $operator_id );
                $preauth_error = $PRE_ORDER_PAYMENT_API_MESSAGE__MISSING_DETAILS;
            }
            else {
                $pre_order->select_all_items( $operator_id );
                $logger->warn( "Unknown response for PreAuth: $psp_preauth_response->{returnCodeReason} ($psp_preauth_response->{returnCodeResult})" );
                $preauth_error = $PRE_ORDER_PAYMENT_API_MESSAGE__UNKNOWN_RESPONSE;
            }
        }
        catch {
            my $error = $_;
            $logger->warn($error);
            $pre_order->select_all_items( $operator_id );
            _fail( $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_PREAUTH );
        };

        _fail( $preauth_error )
            if $preauth_error;

        $logger->debug('Payment Authorised');

        $self->schema->txn_do(sub {
            my $self = shift(@_);

            try {
                my $payinfo = $self->domain_payment->getinfo_payment({
                    reference => $output{preauth_ref},
                });
                $output{psp_ref}    = $payinfo->{providerReference}     if ( $payinfo );

                $pre_auth_db_record = $self->schema->resultset('Public::PreOrderPayment')->create({
                    psp_ref      => $output{psp_ref},
                    preauth_ref  => $output{preauth_ref},
                    pre_order_id => $pre_order->id,
                });

            }
            catch {
                my $error = $_;
                $logger->warn($error);
                $self->schema->txn_rollback();
                $pre_order->select_all_items( $operator_id );
                _fail( $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_UPDATE_ORDER );
            };
        }, $self);
    }

    # ==================================================================
    # Settle Payment
    $logger->debug('Settle payment');

    $self->schema->txn_do(sub {
        my $self = shift(@_);
        my $stock_manager = XTracker::WebContent::StockManagement->new_stock_manager({
            schema     => $self->schema,
            channel_id => $channel->id,
        });

        foreach my $item ($pre_order->pre_order_items) {
            unless ($item->reservation_id) {
                my $reservation_id = create_reservation(
                    $self->schema->storage->dbh,
                    $stock_manager,
                    {
                        customer_id           => $customer->id,
                        customer_nr           => $customer->is_customer_number,
                        first_name            => $customer->first_name,
                        last_name             => $customer->last_name,
                        email                 => $customer->email,
                        channel_id            => $channel->id,
                        channel               => $channel->name,
                        variant_id            => $item->variant->id,
                        operator_id           => $operator_id,
                        department_id         => $self->operator->department_id,
                        reservation_source_id => $pre_order->reservation_source->id,
                        reservation_type_id   => $pre_order->reservation_type->id,
                    }
                );

                my $reservation = $self->schema->resultset('Public::Reservation')->find($reservation_id);

                $reservation->update({
                    ordering_id => 0
                });

                $item->update_reservation_id($reservation_id);
            }
        }
    }, $self);

    unless ($output{settle_ref}) {

        my $settle_error;
        try {
            my $psp_settle_response = $self->domain_payment->settle_payment({
                channel     => $dc_channel,
                coinAmount  => $coinAmount,
                reference   => $output{preauth_ref},
                currency    => $self->payment_currency,
            });

            if ($psp_settle_response->{SettleResponse}{returnCodeResult} == $PSP_RETURN_CODE__SUCCESS) {
                $output{settle_ref} = ref($psp_settle_response->{SettleResponse}{reference})
                                        ? $psp_settle_response->{SettleResponse}{reference}->numify
                                        : $psp_settle_response->{SettleResponse}{reference};
            }
            elsif ($psp_settle_response->{SettleResponse}{returnCodeResult} == $PSP_RETURN_CODE__BANK_REJECT) {
                $settle_error = sprintf( $PRE_ORDER_PAYMENT_API_MESSAGE__BANK_REJECT_AT_SETTLE, $psp_settle_response->{SettleResponse}{extraReason} );
            }
            elsif ($psp_settle_response->{SettleResponse}{returnCodeResult} == $PSP_RETURN_CODE__MISSING_INFO) {
                $settle_error = sprintf( $PRE_ORDER_PAYMENT_API_MESSAGE__MISSING_DETAILS_AT_SETTLE, $psp_settle_response->{SettleResponse}{extraReason});
            }
            else {
                $logger->warn( "Unknown response for Settle: $psp_settle_response->{SettleResponse}{returnCodeReason} ($psp_settle_response->{SettleResponse}{returnCodeResult})" );
                $settle_error = sprintf( $PRE_ORDER_PAYMENT_API_MESSAGE__UNKNOWN_RESPONSE_AT_SETTLE, $psp_settle_response->{SettleResponse}{returnCodeResult}, $psp_settle_response->{SettleResponse}{extraReason} );
            }
        }
        catch {
            my $error = $_;
            $logger->warn($error);
            _fail( $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_SETTLE );
        };

        _fail( $settle_error )
            if $settle_error;

        $logger->debug('Payment Settled');

        $self->schema->txn_do(sub {
            my $self = shift(@_);

            try {
                $pre_auth_db_record->update({
                    settle_ref   => $output{settle_ref},
                    fulfilled    => 1,
                });

                $pre_order->complete_all_items( $operator_id );

                $pre_order->update_status( $PRE_ORDER_STATUS__COMPLETE, $operator_id );

                eval {
                    # don't care if this fails
                    $pre_order->notify_web_app( $self->message_factory );
                };

            }
            catch {
                my $error = $_;
                $logger->warn($error);
                $self->schema->txn_rollback();
                _fail( $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_UPDATE_ORDER );
            };
        }, $self);
    }

    return 1;

}

sub _calculate_coin_amount {
    my ($self) = @_;
    return XT::Domain::Payment->shift_dp( sprintf("%0.2f", round( $self->payment_amount ) ) );
}

sub _fail {
    my ( $message ) = @_;

    die "$message\n";

}

1;
