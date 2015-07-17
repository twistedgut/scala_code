package XTracker::Database::OrderPayment;

=head1 NAME

XTracker::Database::OrderPayment

=cut

use strict;
use warnings;

use Carp;

use Try::Tiny;

use Perl6::Export::Attrs;
use XTracker::Logfile qw( xt_logger );

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :renumeration_class
                                        :renumeration_status
                                        :renumeration_type
                                        :shipment_status
                                    );
use XTracker::Database::Channel     qw( get_channel_details );
use XTracker::Database::Shipment    qw(
                                        get_shipment_info
                                        get_shipment_item_info
                                        get_order_shipment_info
                                        is_standard_or_active_shipment
                                        is_cancelled_item
                                    );
use XTracker::Database::Order       qw(
                                        get_order_info
                                        get_order_total_charge
                                    );
use XTracker::Database::Invoice     qw(
                                        create_invoice
                                        create_invoice_item
                                        get_shipment_sales_invoice
                                        generate_invoice_number
                                        log_invoice_status
                                    );
use XTracker::Vertex                qw(
                                        create_vertex_invoice_from_xt_id
                                        use_vertex_for_shipment
                                    );

use XT::Domain::Payment;
use XTracker::Constants::Payment qw( :psp_return_codes );
use XTracker::Utilities qw( number_in_list );


use vars qw($dbh);

use Data::Dump  qw( pp );

=head1 METHODS

=cut

### Subroutine : create_order_payment               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_order_payment :Export() {

    my ( $dbh, $order_id, $psp_ref, $preauth_ref ) = @_;

    if ( !defined( $order_id ) ) {
        die 'No order id defined';
    }

    if ( !defined( $psp_ref ) ) {
        die 'No psp reference defined';
    }

    if ( !defined( $preauth_ref ) ) {
        die 'No preauth reference defined';
    }

    my $qry = "INSERT INTO orders.payment (orders_id, psp_ref, preauth_ref) VALUES (?, ?, ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute($order_id, $psp_ref, $preauth_ref);

    return;
}

### Subroutine : get_order_payment               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_order_payment :Export() {

    my ( $dbh, $order_id ) = @_;

    if ( !defined( $order_id ) ) {
        return;
    }

    my $qry = "SELECT id, psp_ref, preauth_ref, settle_ref, fulfilled, valid FROM orders.payment WHERE orders_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($order_id);
    my $row = $sth->fetchrow_hashref;

    return $row;
}

### Subroutine : check_order_payment_fulfilled   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub check_order_payment_fulfilled :Export() {

    my ( $dbh, $order_id ) = @_;

    if ( !defined( $order_id ) ) {
        die 'No order id defined';
    }

    my $fulfilled = 1;

    my $qry = "SELECT fulfilled FROM orders.payment WHERE orders_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($order_id);
    while ( my $rows = $sth->fetchrow_arrayref ) {
        $fulfilled = $rows->[0];
    }

    return $fulfilled;

}

### Subroutine : set_order_payment_fulfilled     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_order_payment_fulfilled :Export() {

    my ( $dbh, $order_id, $settle_ref ) = @_;

    if ( !defined( $order_id ) ) {
        die 'No order id defined';
    }

    my $qry = "UPDATE orders.payment SET fulfilled = true, settle_ref = ? WHERE orders_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($settle_ref, $order_id);

    return;
}


=head2 toggle_payment_fulfilled_flag_and_log( $schema, $payment_id, $operator_id, $reason )

  usage        : $boolean = toggle_payment_fulfilled_flag_and_log(
                    $schema,
                    $payment_id,
                    $operator_id,
                    $reason
                 );

  description  : This will toggle the 'fulfilled' flag for the given payment, and then log its change against the operator and reason passed.

  parameters   : A DBiC Schema Connection, A Payment Id, An Operator Id, A Reason
  returns      : The new state of the 'fulfilled' flag

=cut

sub toggle_payment_fulfilled_flag_and_log :Export() {

    my ( $schema, $payment_id, $operator_id, $reason )  = @_;

    die "No Schema Passed"              if ( !defined $schema );
    die "No Payment Id Passed"          if ( !defined $payment_id || $payment_id <= 0 );
    die "No Operator Id Passed"         if ( !defined $operator_id || $operator_id <= 0 );
    die "No Reason Passed"              if ( !defined $reason || $reason eq '' );

    my $retval;

    my $payment = $schema->resultset('Orders::Payment')->find( $payment_id );
    die "Can't find Payment Record for Id: $payment_id"     if ( !defined $payment );

    $schema->txn_do( sub {
            # toggle the state
            my $new_state   = $payment->toggle_fulfilled_flag();
            # now log the change
            $payment->log_payment_fulfilled_changes_rs
                        ->create( {
                                new_state           => $new_state,
                                operator_id         => $operator_id,
                                reason_for_change   => $reason,
                            } );

            if ( $new_state ) {
                # see if there is a Virtual Voucher Only Shipment and
                # if so dispatch it
                my $shipment    = $payment->orders->shipments
                                            ->search( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } )
                                            ->first;
                if ( defined $shipment ) {
                    $shipment->auto_pick_virtual_vouchers( $operator_id );      # First see if there are any Virtual Vouchers to Auto-Pick
                    $shipment->dispatch_virtual_voucher_only_shipment( $operator_id );
                }
            }

            $retval = $new_state;
        } );

    return $retval;
}


### Subroutine : get_order_status     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_order_status :Export() {

    my ( $dbh, $order_nr ) = @_;

    my $qry = "SELECT to_char(o.date, 'DD-MM-YYYY  HH24:MI') as date, os.status, op.fulfilled, o.id as orders_id, o.total_value
                FROM orders o LEFT JOIN orders.payment op ON o.id = op.orders_id, order_status os
                WHERE o.order_nr = ?
                AND o.order_status_id = os.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($order_nr);

    return $sth->fetchrow_hashref();

}

=head2 process_payment

    $order_nr = process_payment( $schema, $shipment_id );

This processes the payment at the Packing Stage, it goes to the PSP if a Card Payment is required and takes the money. This used to be in XTracker::ProcessPayment but was factored out as part of the Gift Vouchers project so that it could be used for Virtual Voucher only orders to Fasttrack Dispatch them. This will therefore be used in the process to take one of these orders off Credit Hold and by the AMQ Consumer XT::DC::Messaging::Consumer::Product when it receives Virtual Voucher Codes to automatically dispatch Virtual Voucher Only orders when appropriate.

=cut

sub process_payment :Export() {
    my ( $schema, $shipment_id )   = @_;

    if ( !defined $schema ) {
        croak "No Schema Handle passed in " . __PACKAGE__ . "::process_payment";
    }
    if ( !$shipment_id ) {
        croak "No Shipment Id passed in " . __PACKAGE__ . "::process_payment";
    }

    if ( ref( $schema ) !~ /Schema/ ) {
        croak "Invalid Schema Object passed in: '" . ref( $schema ) . "' to " . __PACKAGE__ . "::process_payment";
    }

    my $dbh = $schema->storage->dbh;

    # get the Shipment being Packed
    my $shipment = $schema->resultset('Public::Shipment')->find( $shipment_id );

    my $order_rec       = $shipment->order;
    my $order_id        = ( $order_rec ? $order_rec->id : undef );                          # order id for shipment
    my $order_info      = get_order_info( $dbh, $order_id );                                # get order info
    my $shipments       = get_order_shipment_info( $dbh, $order_id );                       # get all shipments on order
    my $order_payment   = get_order_payment( $dbh, $order_id );                             # get payment on order
    my $channel_info    = get_channel_details( $dbh, $order_info->{sales_channel} );        # sales channel info for order

    my $order_nr        = $order_info->{order_nr};
    my $web_conf_section= $channel_info->{config_section};

    # if we have a pre-auth on order
    # and
    # it hasn't been fulfilled we need to take payment
    if ( $order_payment && $order_payment->{fulfilled} == 0 ) {

        # if pre-auth is not valid return to packing screen with msg for user
        if ( $order_payment->{valid} == 0 ) {
            die qq{Pre-Authorisation no longer valid for order $order_nr, please contact Customer Finance};
        }

        # get total charge for order
        my $total_charge = get_order_total_charge($dbh, $order_id);
        xt_logger->debug( qq{Order: $order_nr - total charge calculated = $total_charge} );

        # create payment service object
        my $service = XT::Domain::Payment->new();

        # set up parameters for settle call
        my $params = {};

        $params->{channel}      = config_var('PaymentService_'.$channel_info->{config_section}, 'dc_channel');
        $params->{coinAmount}   = $service->shift_dp( $total_charge );
        $params->{reference}    = $order_payment->{preauth_ref};
        $params->{currency}     = $order_info->{currency};

        # settle pre-auth payment
        xt_logger->debug( "Settle request ". pp( $params ) );
        my $result  = $service->settle_payment( $params );

        # Ensure that the resultCode exists first
        if ( exists $result->{SettleResponse}{returnCodeResult} && $result->{SettleResponse}{returnCodeResult} ) {
            # payment successful - update order payment as 'fulfilled' and store settle ref
            if ( $result->{SettleResponse}{returnCodeResult} == $PSP_RETURN_CODE__SUCCESS ) {
                # save the settle_ref to orders.payment
                set_order_payment_fulfilled( $dbh, $order_id, $result->{SettleResponse}{reference} );
                xt_logger->debug( qq{Payment fulfilled for order $order_nr} );
            }
            # payment unsuccessful - kick user back to packing screen with warning message
            else {
                my $extra_reason = $result->{SettleResponse}{extraReason} // 'unknown';
                xt_logger->info( qq{Unable to take payment for order $order_nr (CoinAmount: $$params{coinAmount}) - Reason: '$extra_reason'} );

                if (number_in_list($result->{SettleResponse}{returnCodeResult},
                        $PSP_RETURN_CODE__UNKNOWN_ERROR,
                        $PSP_RETURN_CODE__INTERNAL_SERVER_ERROR,
                        $PSP_RETURN_CODE__MISSING_INFO )
                ) {
                    die qq{Payment could not be taken for this shipment, please try again or if the problem persists please advise a Line Manager of the situation. Extra Reason: '$extra_reason'};

                }
                # missing info
                elsif ( number_in_list( $result->{SettleResponse}{returnCodeResult},
                        $PSP_RETURN_CODE__CANCELLED_VOIDED,
                        $PSP_RETURN_CODE__DIFFERENT_CURRENCY )
                ) {
                    die qq{Payment could not be taken for this shipment. Please advise a Line Manager of the situation. Extra Reason: '$extra_reason'};
                }
                # service down
                else {
                    die qq{Payment couldn't be taken for this shipment, please try again or if the problem persists please advise a Line Manager of the situation. Extra Reason: '$extra_reason'};
                }
            }
        }
        else {
            die qq{Payment could not be taken for this shipment, please try again or if the problem persists please contact the IT Department.};
        }
    }
    else {
        xt_logger->debug( qq{No payment or payment already fulfilled for order $order_nr} );

        # for Exchange Shipments call the following Method which will notify
        # the PSP of the Exchanges if the Order's Payment Method requires it
        if ( $shipment->is_exchange ) {
            try {
                $shipment->notify_psp_of_exchanged_items();
            } catch {
                my $err     = $_;
                my $err_msg = "Couldn't Update PSP about Exchanged Items for Order/Shipment: '${order_nr}/${shipment_id}', Reason: " . $err;
                xt_logger->error( $err_msg );
                # throw the error back to the Caller
                die $err_msg . "\n";
            };
        }
    }

    # create sales invoices for each order shipment if required
    # only standard shipments are invoiced
    foreach my $shipment_id (keys %{$shipments}){

        # check that no sales invoice has been created for shipment
        if ( !get_shipment_sales_invoice( $dbh, $shipment_id ) ){

            # only standard and active shipments invoiced
            if ( is_standard_or_active_shipment($shipments->{$shipment_id}) ) {

                # Create Invoice
                my $invoice_id = _create_invoice(
                    $schema,
                    $shipment_id,
                    $shipments,
                    $order_info
                );

                # process Vertex invoice if required
                if (use_vertex_for_shipment($dbh, $shipment_id) ) {
                    my $invoice_result = create_vertex_invoice_from_xt_id($dbh, { invoice_id => $invoice_id } );
                    xt_logger->debug( qq{ [FULFILL] USING VERTEX FOR $shipment_id} );
                }
                else {
                    xt_logger->debug( qq{ [FULFILL] NOT USING VERTEX FOR $shipment_id} );
                }
            }
        }
    }

    # return the Order Nr. and the Order's Sales Channel Conf Section
    return ( $order_nr, $web_conf_section );
}

=head2 create_sales_invoice_for_preorder_shipment

    $invoice_id = create_sales_invoice_for_preorder_shipment( $schema, $shipment_obj );

Given a Shipment Object will create a Sales Invoice for it. This is used at Order Import as the money has already been
taken for a Pre-Order so the Sales Invoice can be created as soon as there is an Order. The checks in the
'process_payment' function should prevent another Sales Invoice being created when the Order is Packed.

=cut

sub create_sales_invoice_for_preorder_shipment :Export() {
    my ( $schema, $shipment )   = @_;

    my $order   = $shipment->order;
    return      if ( !$order || !$order->has_preorder );

    my $invoice_id  = _create_invoice(
        $schema,
        $shipment->id,
        { # $shipments
            $shipment->id   => {
                shipping_charge => $shipment->shipping_charge,
                gift_credit     => $shipment->gift_credit,
                store_credit    => $shipment->store_credit,
            },
        },
        { # $order_info
            currency_id => $order->currency_id,
        },
    );

    if ( use_vertex_for_shipment( $schema->storage->dbh, $shipment->id ) ) {
        my $invoice_result = create_vertex_invoice_from_xt_id( $schema->storage->dbh, { invoice_id => $invoice_id } );
    }

    return $invoice_id;
}


# private function used by 'process_payment' to create an invoice after the money has been successfully taken from the PSP
# or if no money needed to be taken (order entirely paid by Store Credit etc.)
sub _create_invoice {

    my ($schema, $shipment_id, $shipments, $order_info) = @_;

    # get the DBH connection
    my $dbh = $schema->storage->dbh;

    my ($invoice_number, $invoice_id, $items);

    $invoice_number = generate_invoice_number($dbh);
    #xt_logger->debug("invoice number: $invoice_number");

    # get Gift Voucher value
    my $order   = $schema->resultset('Public::Shipment')->find( $shipment_id )->order;
    my $tenders = $order->tenders->search( { type_id => $RENUMERATION_TYPE__VOUCHER_CREDIT } );
    my $gift_voucher    = 0;
    while ( my $tender = $tenders->next ) {
        $gift_voucher   += $tender->value;
    }
    $gift_voucher   *= -1;      # make it negative

    $invoice_id = create_invoice(
        $dbh,                                           # $dbh
        $shipment_id,                                   # $shipment_id
        $invoice_number,                                # $invoice_nr
        $RENUMERATION_TYPE__CARD_DEBIT,                 # $type_id  -> renumeration_type(id)
        $RENUMERATION_CLASS__ORDER,                     # $class_id -> renumeration_class(id)
        $RENUMERATION_STATUS__COMPLETED,                # $status   -> renumeration_status(id)
        $shipments->{$shipment_id}{shipping_charge},    # $shipping
        0,                                              # $misc_refund
        0,                                              # $alt_customer_num
        $shipments->{$shipment_id}{gift_credit},        # $gift_credit
        $shipments->{$shipment_id}{store_credit},       # $store_credit
        $order_info->{currency_id},                     # $currency_id
        $gift_voucher                                   # gift voucher amount
    );

    #xt_logger->debug("invoice id: $invoice_id");

    log_invoice_status(
        $dbh,                                           # $dbh
        $invoice_id,                                    # $invoice_id
        $RENUMERATION_STATUS__COMPLETED,                # $status
        $APPLICATION_OPERATOR_ID,                       # $operator_id
    );

    $items = get_shipment_item_info($dbh, $shipment_id);

    # Create Invoice Items
    foreach my $item_id ( keys %{$items} ) {
        if ( not is_cancelled_item($items->{$item_id}) ) {
            #xt_logger->debug( qq{create_invoice_item(..., $invoice_id, $item_id, ...)} );
            create_invoice_item(
                $dbh,
                $invoice_id,
                $item_id,
                $items->{$item_id}{unit_price},
                $items->{$item_id}{tax},
                $items->{$item_id}{duty}
            );
        }
    }

    #xt_logger->debug("returning invoice id: $invoice_id");

    return $invoice_id;
}

=head2 refund_to_psp

    $hash_ref   = refund_to_psp( {
                                amount          => 100.00,
                                channel         => $channel_dbic_obj,
                                settlement_ref  => $settle_ref,
                                id_for_err_msg  => $order_nr or something appropriate to display in the Error Message,
                                label_for_id    => 'Order Nr' or the appropriate label for the above Id,
                            } );

This will use the Payment Service to Refund an Amount for a Settlement Reference back through the PSP.

It will return a Hash Ref. detailing the 'Success' or not and an Error Message on failure.

    {
        success     => 1 or 0,
        error_msg   => "Error Message Goes Here",   # if 'success' is FALSE
    }

=cut

sub refund_to_psp :Export() {
    my $args    = shift;

    # unpack the arguments
    my $total_amount    = $args->{amount};
    my $channel         = $args->{channel};
    my $settle_ref      = $args->{settlement_ref};
    my $id_for_msg      = $args->{id_for_err_msg};
    my $label_for_id    = $args->{label_for_id};


    if( $total_amount <= 0 ) {

        xt_logger->warn("Invalid amount given for refund for ". $total_amount. " amount having settle_ref: ". $settle_ref);
        return {
            success     => 0,
            error_msg   => "Invalid amount given for refund: ". $total_amount,
        };
    }


    # start off expecting it to work!
    my $retval  = {
                success     => 1,
            };

    # refund via Payment Service
    # create payment service object
    my $service = XT::Domain::Payment->new();

    # keep in line with how 'get_invoice_value' returns it's value
    my $fmt_amount  = sprintf( "%.2f", $total_amount );

    # set up parameters for refund call
    my $params = {};
    $params->{channel}              = config_var( 'PaymentService_' . $channel->business->config_section, 'dc_channel' );
    $params->{coinAmount}           = $service->shift_dp( $fmt_amount );
    $params->{settlementReference}  = $settle_ref;

    # refund transaction
    my $result  = $service->refund_payment( $params );

    my $return_code = $result->{RefundResponse}->{returnCodeResult} // 0;

    unless ( $return_code == 1 ) {

        # Build error message for user based on return code.

        my $error_msg = "Unable to refund for ${label_for_id}: " . $id_for_msg . ",  ";

        if ( $return_code == 2 ) {

            # Bank reject.
            $error_msg .= "The transaction has been rejected by the issuing bank.";

        } elsif ( $return_code == 3 ) {

            # Missing info.
            $error_msg .= "Mandatory information missing from transaction.";

        }

        # Add reason returned from service to message.
        if ( $result->{RefundResponse}->{extraReason} && $result->{RefundResponse}->{extraReason} ne '' ) {

            $error_msg .= " Reason: ".$result->{RefundResponse}->{extraReason}."<br>";

        } else {

            $error_msg .= " Reason: Could not find order via PSP Service<br>";

        }

        $retval = {
                success     => 0,
                error_msg   => $error_msg,
            };
    }

    return $retval;
}

1;
