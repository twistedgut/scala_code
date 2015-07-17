package XTracker::Schema::Role::ResultSet::FraudCondition;
use NAP::policy "tt", 'role';

=head1 XTracker::Schema::Role::ResultSet::FraudCondition

A Role for returning a ResultSet of Fraud Conditions.

Currently a Role for:
    * ResultSet::Fraud::StagingCondition
    * ResultSet::Fraud::LiveCondition
    * ResultSet::Fraud::ArchivedCondition

=cut


=head2 by_processing_cost

    $result_set = $self->by_processing_cost;

Return Resultset of Conditions in Ascending order of their Method's 'processing_cost'.

=cut

sub by_processing_cost {
    my $self    = shift;

    return $self->search(
        { },
        {
            join        => 'method',
            order_by    => 'method.processing_cost ASC, me.id ASC',
        }
    );
}

=head2 enabled

    $result_set = $self->enabled;

Returns a Resultset of Conditions which are Enabled.

=cut

sub enabled {
    my $self    = shift;
    return $self->search( { enabled => 1 } );
}

1;
