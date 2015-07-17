package XT::DC::Messaging::Consumer::Orders::PaymentStatusUpdate;
use NAP::policy 'tt', 'class';

extends 'NAP::Messaging::Base::Consumer';
with    'NAP::Messaging::Role::WithModelAccess';

=head1 NAME

XT::DC::Messaging::Consumer::PaymentStatusUpdate

=head1 DESCRIPTION

Processes messages concerning Orders, currently handles:

    * PaymentStatusUpdate - Used for Third Party PSP (eg. PayPal) Payment Updates

=cut

use Data::Dump                      qw(pp);

use XT::DC::Messaging::Spec::Orders;
use XTracker::Config::Local         qw( config_var );


sub routes {
    return {
        destination => {
            PaymentStatusUpdate => {
                code => \&PaymentStatusUpdate,
                spec => XT::DC::Messaging::Spec::Orders->PaymentStatusUpdate(),
            },
        },
    };
}


=head1 METHODS

=head2 PaymentStatusUpdate

This is the method that gets run for processing 'PaymentStatusUpdate' messages to
update the Shipment Status based on the latest Third Party Payment Status that the
PSP reports. This was introduced for 'PayPal' when they have Authroised the payment
that was taken on the Frontend.

This method is for the 'Consumer::Orders::PaymentStatusUpdate' config section in the
'xt_dc_messaging_XTDC1?.conf.tt' files.

=cut

sub PaymentStatusUpdate {
    my ( $self, $message, $header ) = @_;

    # set a debugging flag so time isn't wasted
    # dumping data that's not going to go anywhere
    my $is_debugging = $self->log->is_debug;

    return try {
        $self->log->debug( "'PaymentStatusUpdate' Message: " .  pp( $message ) )    if ( $is_debugging );

        # Is this message for the right DC?
        my $local = lc( config_var('XTracker', 'instance') );

        # just log the important parts of the Payload so that
        # we can see whether a Message was sent for an Order
        $self->log->info(
            "PaymentStatusUpdate - Local Instance: ${local}, " .
            "Order Nr: " . $message->{order_number} . ", " .
            "Channel: " . $message->{channel}
        );

        # As Consumer subscribe to topic, it would receive messages for others DCs.
        # Check it is for the current DC
        unless ( $message->{channel} =~ m/$local/i ) {
            $self->log->debug( pp( $message ) )     if ( $is_debugging );
            $self->log->debug( 'Message received for incorrect channel '.$message->{channel}.' in '.$local );

            return;
        }

        my $schema  = $self->model('Schema');

        # Find channel
        my $channel = $schema->resultset('Public::Channel')->find_by_pws_name( uc( $message->{channel} ) );

        # Channel not found
        unless ( $channel ) {
            $self->log->debug(pp($message))     if ( $is_debugging );
            $self->log->fatal( 'Channel '.$message->{channel}.' not found' );

            return;
        }

        # Find Order based on Order Number & Channel
        my $order = $schema->resultset('Public::Orders')->search( {
            order_nr    => $message->{order_number},
            channel_id  => $channel->id,
        } )->first;
        # Order not found on given channel
        unless ( $order ) {
            $self->log->fatal( "Order Nr: '".$message->{order_number}."' not found on Channel: '".$channel->name."'" );

            return;
        }

        my $payment = $order->search_related( 'payments', { preauth_ref =>   $message->{preauth_ref} } )->first;

        unless( $payment ) {
            $self->log->fatal( "Order Nr: '".$message->{order_number}."' with preauth_ref: '".$message->{preauth_ref}."' not found on Channel: '".$channel->name."'" );

            return;
        }


        $schema->txn_do( sub {
            # get the Standard Class Shipment for the Order and check the Status
            my $shipment = $order->get_standard_class_shipment;
            $shipment->update_status_based_on_third_party_psp_payment_status();
        } );

        return 1;
    }
    catch {
        $self->log->debug( pp( $message ) )     if ( $is_debugging );
        $self->log->fatal( $_ );

        return;
    };
}

