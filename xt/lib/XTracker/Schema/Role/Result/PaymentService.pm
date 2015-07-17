package XTracker::Schema::Role::Result::PaymentService;
use NAP::policy 'role';

requires qw(
    preauth_ref
    settle_ref
);

=head1 NAME

XTracker::Schema::Role::Result::PaymentService

=head1 DESCRIPTION

A role to be consumed by DBIx::Class Result classes to add some common
functionality relating to the Payment Service.

=cut

use XT::Domain::Payment;
use XTracker::Logfile qw( xt_logger );

=head1 METHODS

=head2 domain_payment

Return an instance of an XT::Domain::Payment object.

=cut

sub domain_payment {
    my $self = shift;

    return XT::Domain::Payment->new;

}

=head2 get_pspinfo

    Returns data from PSP for given payment record using preauth_ref

    my $payment = $order->payments->first;

    my $psp_info = $payment->get_pspinfo();

=cut

sub get_pspinfo {
    my $self     = shift;

    return $self->domain_payment->getinfo_payment({ reference => $self->preauth_ref } );

}

=head2 psp_get_refund_history

Returns an ArrayRef of HashRefs with refund history from the PSP, for the
current payment record.

    my $refunds = $object->psp_get_refund_history;

For details on the structure of C<$refunds> see '/refund-information' at (or
the current PSP API documentation):

http://confluence.net-a-porter.com/display/infosec/Payment+Utility+API+Calls

=cut

sub psp_get_refund_history {
    my $self = shift;

    my $info = $self->domain_payment->get_refund_information( $self->settle_ref );

    if ( ref( $info ) eq 'ARRAY' ) {

        return $info;

    } else {

        xt_logger->warn( 'psp_get_refund_history: get_pspinfo response contains missing or invalid refund data' );

    }

    return undef;

}

