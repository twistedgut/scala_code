package XTracker::Schema::ResultSet::Public::Renumeration;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head1 NAME

XTracker::Schema::ResultSet::Public::Renumeration

=cut

use XTracker::Constants::FromDB qw/
    :renumeration_status
    :renumeration_class
    :renumeration_type
/;


=head1 METHODS

=head2 card_debit_type

Returns a ResultSet of Renumeration of Type 'Card Debit'.

=cut

sub card_debit_type {
    my $self = shift;

    return $self->search( {
        renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT,
    } );
}

=head2 not_cancelled

=cut

sub not_cancelled {
    my ($self) = @_;
    $self->search(
        { renumeration_status_id => { '!=' => $RENUMERATION_STATUS__CANCELLED } },
    );
}

=head2 not_yet_complete

Returns a ResultSet of all Renumerations which are not yet Complete.

This will exclude Cancelled Renumerations.

=cut

sub not_yet_complete {
    my $self = shift;

    return $self->not_cancelled->search( {
        renumeration_status_id => {
            'IN' => [
                $RENUMERATION_STATUS__PENDING,
                $RENUMERATION_STATUS__AWAITING_AUTHORISATION,
                $RENUMERATION_STATUS__AWAITING_ACTION,
                $RENUMERATION_STATUS__PRINTED,
            ],
        },
    } );
}

=head2 modifiable

Pending or Awaiting Auth

=cut

sub modifiable {
    my ($self) = @_;
    $self->search(
        { renumeration_status_id => { '<' => $RENUMERATION_STATUS__AWAITING_ACTION } },
    );
}

=head2 for_returns

=cut

sub for_returns {
    my ($self) = @_;
    $self->search(
        { renumeration_class_id => $RENUMERATION_CLASS__RETURN }
    );
}

=head2 for_not_orders

=cut

sub for_not_orders {
    my ($self) = @_;
    $self->search(
        { renumeration_class_id => { '!=' => $RENUMERATION_CLASS__ORDER } }
    );
}

=head2 previous_shipping_refund

=cut

sub previous_shipping_refund {
    my ($self) = @_;

    $self->not_cancelled
         ->for_not_orders
         ->search(
            { renumeration_type_id => [
                $RENUMERATION_TYPE__STORE_CREDIT,
                $RENUMERATION_TYPE__CARD_REFUND ]
            }
          )
         ->get_column('shipping')
         ->sum || 0;
}

=head2 cancel_for_returns

This is used by XT::Domain::Returns before adding/removing/converting return items. This cancels existing Renumerations and removes all renumeration tenders. It updates the status rather than delete the records so that data is not lost.

=cut

sub cancel_for_returns {
    my ( $self, $operator_id )  = @_;

    # check we have exclusively Return Renumerations
    if ( grep { $_->renumeration_class_id != $RENUMERATION_CLASS__RETURN } $self->all ) {
        # if any Non Return Renumerations then don't do anything
        return;
    }

    # check all renumerations are not Completed
    if ( grep { $_->renumeration_status_id == $RENUMERATION_STATUS__COMPLETED } $self->all ) {
        # You can't Cancel a Completed Return Invoice so DIE
        # this might flush out some other bugs where this is
        # hapenning, but it shouldn't be allowed to
        die "Can't Cancel already Completed Invoices";
    }

    $self->search_related('renumeration_tenders')->delete;
    my @renums  = $self->all;
    foreach ( @renums ) {
        $_->update_status( $RENUMERATION_STATUS__CANCELLED, $operator_id );
    }
}

1;
