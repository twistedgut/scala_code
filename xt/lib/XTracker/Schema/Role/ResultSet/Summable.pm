package XTracker::Schema::Role::ResultSet::Summable;

# use NAP::policy qw( role );
use strict;
use warnings;

use MooseX::Role::Parameterized;

=head1 ResultSet::Summable

Generate methods that add up one or more columns from a result set,
returning the total.

The parameter I<sums> is a hash whose keys name methods to be created,
and whose corresponding values are a list of column names to be added
up for that result.

=cut

parameter sums => (
    isa => 'HashRef',
    required => 1
);

role {
    my $p = shift;
    my $sums = $p->sums;

    foreach my $sum ( keys %{$sums} ) {
        my $columns = $sums->{$sum};

        method $sum => sub {
            my $rs = shift;

            my $total = 0;

            foreach my $column ( @$columns ) {
                $total += $rs->get_column( $column )->sum || 0;
            }

            return $total;
        };
    }
};

1;
