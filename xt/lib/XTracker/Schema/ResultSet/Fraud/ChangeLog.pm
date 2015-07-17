package XTracker::Schema::ResultSet::Fraud::ChangeLog;

use NAP::policy "tt";

use base 'DBIx::Class::ResultSet';

=head2 in_display_order

    $result_set = $self->in_display_order;

Will Return Records in the Order for Displaying the log on a page.

=cut

sub in_display_order {
    my $self    = shift;

    return $self->search(
        { },
        {
            order_by => 'me.id DESC',
        }
    );
}

