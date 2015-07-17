package XT::Domain::Order;

use strict;
use warnings;
use Class::Std;

use XTracker::Constants::FromDB         qw( :note_type );

use base qw/ XT::Domain /;

{

    sub START {
        my($self) = @_;

        # FIXME: create factory for payment
    }

    sub update_payment {
        my($self,$order_id,$data) = @_;
        my $schema = $self->get_schema;
        my $payment = undef;

        my $order = $self->get_schema->resultset('Public::Orders')
                                        ->find( $order_id );
        if ( !$order ) {
            xt_logger->warn( __PACKAGE__ . " can't find an Order record for Id: '" . ( $order_id // 'undef' ) . "'" );
            return;
        }

        my $payment_rs = $schema->resultset('Orders::Payment')
            ->search( { orders_id => $order_id } );

        if ($payment_rs->count > 0) {
            if ($payment_rs->count > 1) {
                xt_logger->warn(__PACKAGE__ ." more than one match for "
                    ."update_init_ref");
            }
            $payment = $payment_rs->first;
        }

        if (defined $payment) {
            # before updating, log the existing payment by creating
            # an 'orders.replaced_payment' record so that there
            # is a history of the payments used for the Order
            my $orig_payment = $payment->copy_to_replacement_and_move_logs();

            # update the existing Payment
            $payment->update( $data );

            # if the existing Payment was for a Third Party, create an Order
            # Note to show that a change in Payment Method has happened
            if ( $orig_payment->payment_method->is_third_party ) {
                my $orig_method = $orig_payment->payment_method->payment_method;
                my $new_method  = $payment->payment_method->payment_method;

                # add an Order Note, don't specify an Operator Id so the
                # App. User is used as the Note shouldn't need to be edited
                $order->add_note(
                    $NOTE_TYPE__FINANCE,
                    "Payment Method was Changed from '${orig_method}' to '${new_method}'",
                );
            }
        }

        return;
    }

    # if the Shipment is on Hold for Third Party PSP Reasons such
    # as Payment Pending or Payment Rejected, this method will
    # check to see if the Shipment can be Released from Hold
    # (this will only apply to Standard Class Shipments)
    sub update_shipment_status_based_on_third_party_psp_payment_status {
        my ( $self, $order_id, $operator_id ) = @_;

        my $order = $self->get_schema->resultset('Public::Orders')
                                        ->find( $order_id );
        if ( !$order ) {
            xt_logger->warn( __PACKAGE__ . " can't find an Order record for Id: '" . ( $order_id // 'undef' ) . "'" );
            return;
        }

        my $shipment = $order->get_standard_class_shipment;
        if ( !$shipment ) {
            xt_logger->warn( __PACKAGE__ . " can't find a Standard Class Shipment for Order Id: '" . ( $order_id // 'undef' ) . "'" );
            return;
        }

        $shipment->update_status_based_on_third_party_psp_payment_status( $operator_id );

        return;
    }

}
1;

__END__

=pod

=head1 NAME

XT::Domain::Order;

=head1 AUTHOR

Jason Tang

=cut

