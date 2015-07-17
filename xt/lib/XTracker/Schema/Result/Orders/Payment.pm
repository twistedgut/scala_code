use utf8;
package XTracker::Schema::Result::Orders::Payment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("orders.payment");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "orders.payment_id_seq",
  },
  "orders_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "psp_ref",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "preauth_ref",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "settle_ref",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "fulfilled",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "valid",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "payment_method_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("payment_orders_id_key", ["orders_id"]);
__PACKAGE__->add_unique_constraint(
  "payment_orders_preauth_ref_key",
  ["orders_id", "preauth_ref"],
);
__PACKAGE__->add_unique_constraint("payment_orders_psp_ref_key", ["orders_id", "psp_ref"]);
__PACKAGE__->has_many(
  "log_payment_fulfilled_changes",
  "XTracker::Schema::Result::Orders::LogPaymentFulfilledChange",
  { "foreign.payment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_payment_preauth_cancellations",
  "XTracker::Schema::Result::Orders::LogPaymentPreauthCancellation",
  { "foreign.orders_payment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_payment_valid_changes",
  "XTracker::Schema::Result::Orders::LogPaymentValidChange",
  { "foreign.payment_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "orders",
  "XTracker::Schema::Result::Public::Orders",
  { id => "orders_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "payment_method",
  "XTracker::Schema::Result::Orders::PaymentMethod",
  { id => "payment_method_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dt82RyWzvsHfYygfuZT38Q

=head1 NAME

XTracker::Schema::Result::Orders::Payment

=head1 DESCRIPTION

Schema file for the orders.payment table.

=cut

use Carp;

# this is for the PSP Service
use XT::Domain::Payment;
use XTracker::Constants     qw( :application );
use XTracker::Config::Local qw( config_var );
use XTracker::Logfile       qw( xt_logger );
use XTracker::Utilities     qw( trim );

=head1 METHODS

=head2 create

=cut

sub create {

    my ( $self, $order_id, $psp_ref, $preauth_ref ) = @_;

    if ( !defined( $order_id ) ) {
        die 'No order id defined';
    }

    if ( !defined( $psp_ref ) ) {
        die 'No psp reference defined';
    }

    if ( !defined( $preauth_ref ) ) {
        die 'No preauth reference defined';
    }

    my $schema = $self->get_schema;

    my $record = $schema->resultset('Orders::Payment')->create({
                                                                    'orders_id'     => $order_id,
                                                                    'psp_ref'       => $psp_ref,
                                                                    'preauth_ref'   => $preauth_ref,
                                                               });

    return $record->id;

}

=head2 check_fulfilled

=cut

sub check_fulfilled {

    my ( $self, $order_id ) = @_;

    if ( !defined( $order_id ) ) {
        die 'No order id defined';
    }

    my $schema = $self->get_schema;

    # default fulfilled flag to true - this covers off any orders without
    # payments (e.g. store credit only) which are already fulfilled
    my $fulfilled = 1;

    # get payment record for order
    my $record = $schema->resultset('Orders::Payment')->find( $order_id );

    if ($record) {
        $fulfilled = $record->fulfilled;
    }

    return $fulfilled;

}


=head2 invalidate

Invalidate the Order Payment by setting 'valid' to false.

    my $order_payment = $schema->resultset('Orders::Payment')->find( $id );
    $order_payment->invalidate;

=cut

sub invalidate {
    my $self = shift;

    if ( $self->update( { valid => 0 } ) ) {

        $self->log_payment_valid_changes->create( {
            new_state => 0,
        } );

    }

    return;

}


=head2 validate

Validate the Order Payment by setting 'valid' to true.

    my $order_payment = $schema->resultset('Orders::Payment')->find( $id );
    $prder_payment->validate;

=cut

sub validate {
    my $self = shift;

    if ( $self->update( { valid => 1 } ) ) {

        $self->log_payment_valid_changes->create( {
            new_state => 1,
        } );

    }

    return;

}

=head2 set_preauth_reference

=cut

sub set_preauth_reference {

    my ( $self, $order_id, $preauth_ref ) = @_;

    if ( !defined( $order_id ) ) {
        die 'No order id defined';
    }

    if ( !defined( $preauth_ref ) ) {
        die 'No preauth reference defined';
    }

    my $schema = $self->get_schema;

    # get payment record for order
    my $record = $schema->resultset('Orders::Payment')->find( $order_id );

    if ($record) {
        $record->preauth_ref( $preauth_ref );
        $record->update;
    }
    else {
        die "Could not find payment record for order";
    }

    return;

}

=head2 fulfill

=cut

sub fulfill {

    my ( $self, $order_id ) = @_;

    if ( !defined( $order_id ) ) {
        die 'No order id defined';
    }

    my $schema = $self->get_schema;

    # get payment record for order
    my $record = $schema->resultset('Orders::Payment')->find( $order_id );

    if ($record) {
        $record->fulfilled( 1 );
        $record->update;
    }
    else {
        die "Could not find payment record for order";
    }

    return;

}

=head2 toggle_fulfilled_flag

This toggles the fulfilled flag from true -> false or false -> true. Returns
the new state.

=cut

sub toggle_fulfilled_flag {

    my $self    = shift;

    my $new_state;

    if ( $self->fulfilled ) {
        $new_state  = 0;
    }
    else {
        $new_state  = 1;
    }

    $self->update( { fulfilled => $new_state } );

    return $new_state;
}

=head2 preauth_cancelled

This returns true if the Pre-Auth ref has been Cancelled.

=cut

sub preauth_cancelled {
    my $self    = shift;
    return $self->log_payment_preauth_cancellations
                    # specifing the 'preauth_ref' is deliberate as you can
                    # overwrite the payment record with new preauths using
                    # the 'Pre-Authorise Order' page and you want to know
                    # whether the current one has been cancelled
                    ->get_preauth_cancelled_success( $self->preauth_ref )
                        ->count();
}

=head2 preauth_cancelled_failure

This returns true if the Pre-Auth ref has had Cancelled Failures.

=cut

sub preauth_cancelled_failure {
    my $self    = shift;
    return $self->log_payment_preauth_cancellations
                    # specifing the 'preauth_ref' is deliberate as you can
                    # overwrite the payment record with new preauths using
                    # the 'Pre-Authorise Order' page and you want to know
                    # whether the current one has been cancelled
                    ->get_preauth_cancelled_failure( $self->preauth_ref )
                        ->count();
}

=head2 preauth_cancelled_attempted

This returns true if the Pre-Auth ref has has Cancelled Attempts.

=cut

sub preauth_cancelled_attempted {
    my $self    = shift;
    return $self->log_payment_preauth_cancellations
                    # specifing the 'preauth_ref' is deliberate as you can
                    # overwrite the payment record with new preauths using
                    # the 'Pre-Authorise Order' page and you want to know
                    # whether the current one has been cancelled
                    ->get_preauth_cancelled_attempts( $self->preauth_ref )
                        ->count();
}


=head2 psp_cancel_preauth

    my $result  = $self->psp_cancel_preauth( {
                                    context => $context,
                                    operator_id => $operator_id,
                                } );

This will send a 'cancel' request to the PSP to cancel the PreAuth for a payment. Pass in a 'Context' to indicate at
what point this method is being called and an Operator Id for the operator who is cancelling the Pre-Auth. Both Context
and the Operator Id are optional and in the case of the Operator Id will be defaulted to the Application User.

It will return the following:

On Success:
    $result = {
        success => 1,
        message => 'Ref: xxxxxx',
    }

On Failure:
    $result = {
        error   => 1,
        message => 'Failure Message',
    }

=cut

sub psp_cancel_preauth {
    my ( $self, $args ) = @_;

    # get the context and operator or set defaults if they are absent
    my $context     = $args->{context} || "Unknown";
    my $operator_id = $args->{operator_id} || $APPLICATION_OPERATOR_ID;

    my $retval  = {
                context     => $context,
                operator_id => $operator_id,
            };

    # don't do it if the payment has been fulfilled or already Cancelled
    if ( !$self->fulfilled && !$self->preauth_cancelled ) {
        my $order   = $self->orders;                    # get the order record for this Payment
        my $service = XT::Domain::Payment->new();       # set-up to talk to the PSP

        # params to pass to the PSP
        my $params  = {
                preAuthReference    => $self->preauth_ref,
            };
        # call the PSP to cancel the Pre-Auth
        my $result  = $service->cancel_preauth( $params );

        if ( defined $result && $result->{CancelResponse}{returnCodeResult} == 1 ) {
            # success
            $retval->{success}  = 1;
            $retval->{message}  = "Ref: ".$result->{CancelResponse}{reference};
        }
        else {
            # failure
            $retval->{error}    = 1;
            if ( !defined $result ) {
                $retval->{message}  = "Result from PSP came back Undefined - Can't determine Success or Failure of Pre-Auth Cancellation";
            }
            else {
                my $response    = $result->{CancelResponse};
                # make up the message to show back to the user on the page
                $retval->{message}  = "(".$response->{returnCodeResult}.") " . $response->{returnCodeReason}
                                      . ( defined $response->{extraReason} && $response->{extraReason} ne "" ? " (".$response->{extraReason}.")" : "" )
                                      . ( defined $response->{reference} && $response->{reference} ne "" ? " (Ref: ".$response->{reference}.")" : "" )
                                      ;
            }
        }

        # log what happened
        my $log_args    = {
                    cancelled                => ( exists( $retval->{success} ) ? 1 : 0 ),
                    preauth_ref_cancelled    => $self->preauth_ref,
                    context                  => $context,
                    message                  => $retval->{message},
                    operator_id              => $operator_id,
                };
        $self->create_related( 'log_payment_preauth_cancellations', $log_args );
    }
    else {
        # don't need to log what happens here as it
        # shouldn't have been called in the first place
        $retval->{error}    = 2;        # indicate the level of error meant nothing was done
        if ( $self->fulfilled ) {
            $retval->{message}  = "Pre-Auth already Fulfilled (PSP Ref/PreAuth Ref): ".$self->psp_ref."/".$self->preauth_ref;
        }
        else {
            $retval->{message}  = "Pre-Auth already Cancelled";
        }
    }


    return $retval;
}

=head2 psp_refund

TODO: This method should call the new 'XTracker::Database::OrderPayment::refund_to_psp' function that
      is a general function to Refund back to the PSP an Amount for a Settlement Reference rather than
      the process be tied to just 'orders.payment'

=cut

sub psp_refund {
    my $self = shift;
    my ( $total_amount, $items ) = @_;

    if ( defined $items && ref( $items ) ne 'ARRAY' ) {
        xt_logger->warn(
            'List of items given for the creation of refund (' . ref( $items ) .
            ') is not an ArrayRef for settle_ref : ' . $self->settle_ref
        );
        croak "Invalid list of items given for creation of refund: ". $total_amount;
    }

    if( $total_amount <= 0 ) {
        xt_logger->warn( "Invalid amount given for creation of refund for ". $total_amount . " amount having settle_ref : ".$self->settle_ref);
        croak "Invalid amount given for creation of refund: ". $total_amount;
    }

    # refund via Payment Service

    # create payment service object
    my $service = XT::Domain::Payment->new();

    # keep in line with how 'get_invoice_value' returns it's value
    my $fmt_amount  = sprintf( "%.2f", $total_amount );

    # set up parameters for refund call
    my $params = {};
    $params->{channel}              = config_var('PaymentService_' . $self->orders->channel->business->config_section, 'dc_channel');
    $params->{coinAmount}           = $service->shift_dp( $fmt_amount );
    $params->{settlementReference}  = $self->settle_ref;
    $params->{refundItems}          = $items,

    # refund transaction
    my $result  = $service->refund_payment( $params );

    unless ( $result->{RefundResponse}->{returnCodeResult} == 1 ) {

        # Build error message for user based on return code.

        my $error_msg = "Unable to refund for Order Nr: " . $self->orders->order_nr . ",  ";

        if ( $result->{RefundResponse}->{returnCodeResult} == 2 ) {

            # Bank reject.
            $error_msg .= "The transaction has been rejected by the issuing bank.";

        } elsif ( $result->{RefundResponse}->{returnCodeResult} == 3 ) {

            # Missing info.
            $error_msg .= "Mandatory information missing from transaction.";

        }

        # Add reason returned from service to message.
        if ( $result->{RefundResponse}->{extraReason} ne '') {

            $error_msg .= " Reason: ".$result->{RefundResponse}->{extraReason}."<br>";

        } else {

            $error_msg .= " Reason: Could not find order via PSP Service<br>";

        }

        die $error_msg;

    }

    return;
}



=head2 method_is_credit_card

    $boolean = $self->method_is_credit_card;

Returns TRUE or FALSE depending on whether the Payment Method used
was a Credit Card or not.

=cut

sub method_is_credit_card {
    my $self    = shift;
    return ( $self->payment_method->is_card ? 1 : 0 );
}

=head2 method_is_third_party

    $boolean = $self->method_is_third_party;

Returns TRUE or FALSE depending on whether the Payment Method used
was a Third Party PSP such as PayPal.

=cut

sub method_is_third_party {
    my $self    = shift;
    return ( $self->payment_method->is_third_party ? 1 : 0 );
}

=head2 get_internal_third_party_status

    $record_obj = $self->get_internal_third_party_status;

Returns the Internal version of the Third Party Status as returned
by the PSP. Will return 'undef' if the Payment's Method is not for
a Third Party PSP.

=cut

sub get_internal_third_party_status {
    my $self    = shift;

    return      if ( !$self->method_is_third_party );

    # get the status from the PSP
    my $psp_info = $self->get_pspinfo;
    my $third_party_status = $psp_info->{current_payment_status};

    if ( !$third_party_status ) {
        warn "No 'current_payment_status' found in PSP Info for Payment (" . $self->id . ") using a Third Party";
        return;
    }

    # get the Internal Status for the Third Party Status
    return $self->payment_method
                    ->get_internal_third_party_status_for( $third_party_status );
}

=head2 notify_psp_of_address_change_and_validate

    $boolean = $self->notify_psp_of_address_change_and_validate( $dbic_address_rec );

If the Payment hasn't already been Fulfilled and the Payment Method requires it, then the
PSP will be notified that there has been a Shipping Address change. The PSP returns TRUE
or FALSE based on whether the Payment Provider deems the new Address valid.

If there are any problems whilst calling the PSP then FALSE will be returned as the validity
of the Address couldn't be determined.

This is used initially just for PayPal payments.

=cut

sub notify_psp_of_address_change_and_validate {
    my ( $self, $address_rec ) = @_;

    # don't talk to the PSP if Payment has already been Fulfilled
    return 1    if ( $self->fulfilled );

    # don't talk to the PSP if the Payment Method doesn't require it
    return 1    unless( $self->payment_method->notify_psp_of_address_change );

    my $order         = $self->orders;
    my $customer      = $order->customer;
    my $order_nr      = $order->order_nr;
    my $customer_name = trim( join( ' ',
        $address_rec->first_name,
        $address_rec->last_name,
    ) );

    my $service = XT::Domain::Payment->new();
    my $result  = $service->reauthorise_address( {
        reference     => $self->preauth_ref,
        order_number  => $order_nr,
        customer_name => $customer_name,
        first_name    => $address_rec->first_name,
        last_name     => $address_rec->last_name,
        address       => $address_rec,
    } );
    my $return_code = $result->{returnCodeResult} // '';

    my $retval;

    if ( $return_code eq '1' ) {
        # success
        $retval = 1;
    }
    elsif ( $return_code eq '-3' ) {
        # failed payment provider validation, most likely
        # because the Address is invalid so log exact reason
        # but for now callers can assume this is the case
        $retval = 0;

        xt_logger->info(
            "PSP Address Change Invalid for Order: ${order_nr}, " .
            "Reason: '${return_code}' - '" . ( $result->{returnCodeReason} // 'undef' ) . "', " .
            "Extra: '" . ( $result->{extraReason} // 'undef' ) . "'"
        );
    }
    else {
        # some other reason for failure, so log it as a warning and
        # return FALSE as it can't be said that the Address is Valid
        $retval = 0;

        xt_logger->warn(
            "Failed whilst Notifying PSP of Address Change for Order: ${order_nr}, " .
            "Reason: '${return_code}' - '" . ( $result->{returnCodeReason} // 'undef' ) . "', " .
            "Extra: '" . ( $result->{extraReason} // 'undef' ) . "'"
        );
    }

    return $retval;
}

=head2 amount_exceeds_threshold

    $boolean = $self->amount_exceeds_threshold( 100.45 );
        or
    undef    = $self->amount_exceeds_threshold( 100.45 );

This will call the PSP to see if a new amount would exceed the limit that
we can go over before requiring a new Pre-Auth. It will return either
TRUE or FALSE depending on the result from the PSP or 'undef' if there
was an error during the call to the PSP.

The return of 'undef' can be used to tell the caller to use a fallback
threshold.

=cut

sub amount_exceeds_threshold {
    my ( $self, $new_amount ) = @_;

    # the amount needs to be in 'pence'
    my $usp_amount = sprintf( '%d', ( $new_amount * 100 ) );

    my $service = XT::Domain::Payment->new();
    my $result  = $service->amount_exceeds_provider_threshold( {
        reference   => $self->preauth_ref,
        newAmount   => $usp_amount,
    } );

    return      if ( !$result || !defined $result->{result} );
    return (
        $result->{result} eq '1'
        ? 1
        : 0
    );
}

=head2 copy_to_replacement_and_move_logs

    my $replaced_payment_obj = $self->copy_to_replacement_and_move_logs();

This will create a new record in the 'orders.replaced_payment' table and
copy the Values of the Payment to it. It will also move the following logs
associated with the Payment to their Replaced Payment equivalents:

 All in the 'orders' schema:
    log_payment_preauth_cancellation  -->  log_replaced_payment_preauth_cancellation
    log_payment_fulfilled_change      -->  log_replaced_payment_fulfilled_change
    log_payment_valid_change          -->  log_replaced_payment_valid_change

The original log records WILL be Deleted. The original Payment record
will NOT be Deleted.

The new 'orders.replaced_payment' record will be returned.

=cut

sub copy_to_replacement_and_move_logs {
    my $self = shift;

    # create an 'orders.replaced_payment' record
    my $order = $self->orders;  # '->orders' is not a ResultSet but a Record
    my $replaced_payment = $order->create_related( 'replaced_payments', {
        map { $_ => $self->$_ }
            qw(
                psp_ref
                preauth_ref
                settle_ref
                fulfilled
                valid
                payment_method_id
            )
    } );

    # move all the logs
    $self->log_payment_preauth_cancellations
            ->move_to_replaced_payment_log_and_delete( $replaced_payment );
    $self->log_payment_fulfilled_changes
            ->move_to_replaced_payment_log_and_delete( $replaced_payment );
    $self->log_payment_valid_changes
            ->move_to_replaced_payment_log_and_delete( $replaced_payment );

    return $replaced_payment->discard_changes;
}


use Moose;
with 'XTracker::Schema::Role::Result::PaymentService';

1;
