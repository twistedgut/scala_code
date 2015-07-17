package XTracker::Schema::ResultSet::Orders::LogPaymentFulfilledChange;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

# load this so 'UNION's can be done with this table
__PACKAGE__->load_components("Helper::ResultSet::SetOperations");

use Moose;
with 'XTracker::Schema::Role::ResultSet::MovePaymentLogs',
     'XTracker::Schema::Role::ResultSet::Orderable' => {
        order_by => {
            date_changed => 'date_changed',
         }
     };

=head1 NAME

XTracker::Schema::ResultSet::Orders::LogPaymentFulfilledChange

=cut


=head1 METHODS

=head2 get_all_payment_fulfilled_change_logs_for_order_id

    $result_set = $self->get_all_payment_fulfilled_change_logs_for_order_id( $order_id );

Gets the Payment Fulfilled Change logs for an Order Id including any Replaced
Logs for previous Payments. Pass in the Order Id of the Order whose logs you
wish to get.

This uses a UNION to combine the two logs together and please be aware that to
do this 'DBIx::Class::ResultClass::HashRefInflator' has to be used and as such
DateTime column values will not be inflated as DateTime objects and so will need
to be done at a later stage.

=cut

sub get_all_payment_fulfilled_change_logs_for_order_id {
    my ( $self, $order_id ) = @_;

    my $schema = $self->result_source->schema;

    # list common Columns to retrieve
    my @columns = qw(
        operator_id
        new_state
        reason_for_change
        date_changed
    );

    # list the columns that come from the
    # respective Payment tables without a prefix
    my @payment_cols = qw(
        psp_ref
        preauth_ref
        settle_ref
        payment_method_id
    );

    # get this ResultSet's logs for the Order
    my $log_rs = $self->search(
        {
            'payment.orders_id' => $order_id,
        },
        {
            columns => [
                @columns,
                { name => 'operator.name' },
                # add the correct prefix for the Payment columns,
                # but use the field name as the Alias for the UNION
                map {
                    { $_ => 'payment.' . $_ }
                } @payment_cols,
            ],
            join => [ qw( payment operator ) ],
            # this is required so that when in a UNION the ResultClass's are all the same
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        }
    );

    # get any Replaced Logs for the Order
    my $replaced_log_rs = $schema->resultset('Orders::LogReplacedPaymentFulfilledChange')->search(
        {
            'replaced_payment.orders_id' => $order_id,
        },
        {
            columns => [
                @columns,
                { name => 'operator.name' },
                # add the correct prefix for the Payment columns,
                # but use the field name as the Alias for the UNION
                map {
                    { $_ => 'replaced_payment.' . $_ }
                } @payment_cols,
            ],
            join => [ qw( replaced_payment operator ) ],
            # this is required so that when in a UNION the ResultClass's are all the same
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        }
    );

    # combine them both in a UNION
    return $log_rs->union_all( [ $replaced_log_rs ] );
}


1;
