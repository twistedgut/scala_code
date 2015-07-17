package XTracker::Schema::Role::Result::FraudList;

use NAP::policy 'role';

=head2 resolved_list_items

Return an ArrayRef of all 'Resolved' list items.

Resolved means; where the values stored in each list have been looked up
using the associated helper methods.

=cut

sub resolved_list_items {
    my $self = shift;

    # Get all the available ID -> Value mappings.
    my $lookup = $self->list_type->get_values_from_helper_methods;

    # Return an ArrayRef of resolved list items.
    return [ map { $lookup->{ $_->value } } $self->list_items->all ];

}

=head2 resolved_list_items_as_text

Returns a string of all the 'Resolved' list items (see
<Cresolved_list_items>), joined together using commas.

=cut

sub resolved_list_items_as_text {
    my $self = shift;

    return join( ', ', @{ $self->resolved_list_items } );

}

=head2 all_list_items

Returns an ArrayRef of all list items.

=cut

sub all_list_items {
    my $self = shift;

    return [ map { $_->value } $self->list_items->all ];
}

1;
