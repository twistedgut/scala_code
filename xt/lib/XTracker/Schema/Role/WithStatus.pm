package XTracker::Schema::Role::WithStatus;

# goes a bit wonky using NAP::policy
# use NAP::policy qw( role );
use strict;
use warnings;

use MooseX::Role::Parameterized;

=head1 WithStatus

Generate helper methods for dealing with status.

Given a parameter I<column>, which names the column in each row that
stores its status value, and given a hash I<statuses> of I<name> =>
I<status_value> mappings, create a method called I<is_name> that
returns true if-and-only-if the current row's status column matches
status I<status_value>.

By default, numeric comparisons are used, but you can force string
comparisons for non-numeric status codes by passing the optional
I<type> parameter and setting it to anything but C<num>.

In future, fancier type comparison could be supported by, say, having
an enum of supported types with associated comparison functions, and
building the subroutine based on those.  But this will do for now.

=cut

parameter column => (
    isa => 'Str',
    required => 1
);

parameter type => (
    isa => 'Str',
    required => 0,
    default => 'num'
);

parameter statuses => (
    isa => 'HashRef',
    required => 1
);

role {
    my $p = shift;

    my ( $column, $column_type ) = ( $p->column, $p->type );

    foreach my $short_name ( keys %{$p->statuses} ) {
        my $status = $p->statuses->{$short_name};

        if ( $column_type eq 'num' ) {
            method "is_$short_name" => sub {
                return ( shift->$column == $status ) ? 1 : 0 ;
            };
        }
        else {
            method "is_$short_name" => sub {
                return ( shift->$column eq $status ) ? 1 : 0 ;
            };
        }
    }
};

1;
