package XTracker::Schema::ResultSet::Public::CustomerAction;
# vim: ts=8 sts=4 et sw=4 sr sta

use NAP::policy "tt";
use base 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB qw(
    :customer_action_type
);

=head1 NAME

XTracker::Schema::ResultSet::Public::CustomerAction

=head1 METHODS

=head2 get_new_high_values

Return all 'New High Value' records.

    my $new_high_value_records = $schema
        ->resultset('Public::CustomerAction')
        ->get_new_high_values;

=cut

sub get_new_high_values {
    my $self = shift;

    return $self->search( {
        customer_action_type_id => $PUBLIC_CUSTOMER_ACTION_TYPE__NEW_HIGH_VALUE,
    } );

}

=head2 get_last_new_high_value

Get the latest 'New High Value' record based on 'created_date'.

Returns a C<Public::CustomerAction> C<Result> object.

    my $last_new_high_value_record = $schema
        ->resultset('Public::CustomerAction')
        ->get_last_new_high_value;

=cut

sub get_last_new_high_value {
    my $self = shift;

    # Get all the 'New High Value' records, ordered by date and
    # id (because date is not unique) and return the first one.
    return $self->search( {
        customer_action_type_id => $PUBLIC_CUSTOMER_ACTION_TYPE__NEW_HIGH_VALUE,
    }, {
        order_by => {
            -desc => [ qw(
                date_created
                id
            ) ],
        },
    } )->first;

}

=head2 add_customer_new_high_value( \%args )

Create a 'New High Value' record for a customer.

This method is designed to ONLY be used when chaining of a Public::Customer
record, as the customer_id is required and not provided by this method.

The argument 'operator_id' is required.

    my $new_high_value_record = $schema
        ->resultset('Public::Customer')
        ->find( $id )
        ->add_customer_new_high_value( {
            operator_id => $operator_id,
        } );

=cut

sub add_customer_new_high_value {
    my ( $self, $args ) = @_;

    die "operator_id is required for " . __PACKAGE__ . "->add_new_customer_high_value"
        unless $args->{operator_id};

    return $self->create( {
        operator_id             => $args->{operator_id},
        customer_action_type_id => $PUBLIC_CUSTOMER_ACTION_TYPE__NEW_HIGH_VALUE,
    } );

}

1;
