package XTracker::Schema::Role::ResultSet::Orderable;

# use NAP::policy qw( role );
use strict;
use warnings;

use MooseX::Role::Parameterized;

=head1 ResultSet::Orderable

Create methods for ordering a result set.

Required parameter I<order_by> is a hash of keys that point to either
a comma-separated string of column names, or an array of column names,
and the hash key is used in the method names.

Each named array I<foo> produces two methods, one named
I<order_by_foo> for the ascending sort, and one I<order_by_foo_desc>
for the descending one.

The methods generated discover the current source alias and prepend
that to the names passed in, to avoid ambiguities.  In future, a
mechanism to override this default in circumstances where it is
unhelpful could be added, perhaps.

=cut

parameter order_by => (
    isa => 'HashRef',
    required => 0
);

role {
    my $p = shift;

    foreach my $order ( keys %{$p->order_by} ) {
        my $column_def = $p->order_by->{$order};
        my @columns;

        if ( ref $column_def eq 'ARRAY' ) {
            @columns = @$column_def;
        }
        else {
            @columns = split ( /,/, $column_def );
        }

        # couldn't really see the point of abstracting out into a data
        # structure the 'asc', 'desc' portion, along with its
        # associated hard-coded test, since we're unlikely ever to get
        # other directions of sort besides ascending and descending on
        # result sets, so it seemed like flexibility to no useful end

        foreach my $dir ( qw( asc desc ) ) {
            my $name = "order_by_$order";

            $name .= "_$dir" unless $dir eq 'asc';

            method $name => sub {
                my $rs = shift;
                my $me  = $rs->current_source_alias;

                my $cols = [ map { "${me}.$_" } @columns ];

                return $rs->search( { }, { order_by => { -$dir  => $cols } } );
            };
        }
    }
};

1;
