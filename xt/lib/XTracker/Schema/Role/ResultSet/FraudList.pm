package XTracker::Schema::Role::ResultSet::FraudList;
use NAP::policy 'role';

=head1 XTracker::Schema::Role::ResultSet::FraudList

A Role for returning a ResultSet of Fraud Lists.

Currently a Role for:
    * ResultSet::Fraud::StagingList
    * ResultSet::Fraud::LiveList
    * ResultSet::Fraud::ArchivedList

=cut

=head2 values_by_list_id

    $array_ref_of_list_items= $self->values_by_list_id( $list_id );

Return an array reference containing the values of each list item in a given
list.

=cut

sub values_by_list_id {
    my $self    = shift;
    my $list_id = shift;

    die "You must pass in the list id" unless $list_id;

    my $list = $self->find( $list_id );

    return @{$list->all_list_items};
}

1;
