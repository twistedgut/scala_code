package XTracker::Schema::ResultSet::Fraud::Method;

use NAP::policy "tt";

use base 'DBIx::Class::ResultSet';

sub get_methods_in_alphabet_order {
        my $self = shift;
    return $self->search({}, {order_by => {-asc => 'description'}})->all;
}
