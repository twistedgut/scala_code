package XTracker::Schema::ResultSet::Orders::Payment;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub get_payment_by_psp_ref {

    my ( $resultset, $psp_ref ) = @_;

    my $payment_rs = $resultset->search(
        {
            psp_ref => { '-in' => $psp_ref },
        },
        {
            'join'     => [qw( orders )],
            '+select'  => [qw( orders.order_nr )],
            '+as'      => [qw( order_nr )],
            'prefetch' => [qw( orders )]
        }
    );

    return $payment_rs;

}

=head2 invalidate

Invalidate all Order Payments by setting 'valid' to false.

In Reality, there will only ever be one Payment (because of the primary
key), but because the relationship is has_many, we assume otherwise.

    my $order_payments = $schema->resultset('Orders::Payment');
    $order_payments->invalidate;

=cut

sub invalidate {
    my $self = shift;

    foreach my $payment ( $self->all ) {

        $payment->invalidate;

    }

}

=head2 validate

Validate all Order Payments by setting 'valid' to true.

In Reality, there will only ever be one Payment (because of the primary
key), but because the relationship is has_many, we assume otherwise.

    my $order_payments = $schema->resultset('Orders::Payment');
    $order_payments->validate;

=cut

sub validate {
    my $self = shift;

    foreach my $payment ( $self->all ) {

        $payment->validate;

    }

}

1;

