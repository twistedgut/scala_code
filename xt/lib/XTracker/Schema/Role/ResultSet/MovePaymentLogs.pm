package XTracker::Schema::Role::ResultSet::MovePaymentLogs;
use NAP::policy     qw( role );

=head1 NAME

XTracker::Schema::Role::ResultSet::MovePaymentLogs

=head1 DESCRIPTION

A Role for moving Logs that are created against an 'orders.payment' record
when that record is being replaced and moved to the 'orders.replaced_payment'
table. This Role will move those Logs to their Replaced Payment equivalent
Log tables.

=cut


=head1 METHODS

=head2 move_to_replaced_payment_log_and_delete

    $self->move_to_replaced_payment_log_and_delete( $replaced_payment_obj );

=cut

sub move_to_replaced_payment_log_and_delete {
    my ( $self, $replaced_payment ) = @_;

    my @recs = $self->all;

    foreach my $rec ( @recs ) {
        $rec->copy_to_replaced_payment_log( $replaced_payment );
        $rec->delete;
    }

    return;
}


1;
