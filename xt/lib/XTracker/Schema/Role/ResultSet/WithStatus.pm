package XTracker::Schema::Role::ResultSet::WithStatus;

# use NAP::policy qw( role );
use strict;
use warnings;

use MooseX::Role::Parameterized;

=head1 ResultSet::WithStatus

Generate helper methods for dealing with status.

Given a parameter I<column>, which names the column in each row that
stores its status value, and given a hash I<statuses> of I<name> =>
I<status_value> mappings, for each hash entry this role creates:

=over 2

=item a method named I<name> that returns only those items from the
current result set whose status matches I<status_value>

=item a method named I<not_name> that excludes those rows whose status matches
I<status_value>, while returning all the rest

=item a method named I<are_all_name> which returns true if-and-only-if
all the statuses for the rows in the result set match I<status_value>

=back

Additionally, if the optional parameter I<update_with> is provided,
this role adds a method, named I<update_with>'s value, that iterates
over all the items in the result set, calling the item's matching
method to update the item's status.  The method expects a I<status_value>
to apply to the whole result set, and passes through any other
optional arguments, such as an operator ID.

=cut

parameter column => (
    isa => 'Str',
    required => 1
);

parameter statuses => (
    isa => 'HashRef',
    required => 1
);

parameter update_with => (
    isa => 'Str',
    required => 0,
    default => ''
);

role {
    my $p = shift;

    my $column = $p->column;

    foreach my $short_name ( keys %{$p->statuses} ) {
        my $status = $p->statuses->{$short_name};

        my $not_name = "not_$short_name";

        method $short_name => sub {
            return shift->search( { $column => $status } );
        };

        method $not_name => sub {
            return shift->search( { $column => { '!=' => $status } } );
        };

        method "are_all_$short_name" => sub {
            my $self = shift;

            return 0 unless $self->count;

            # note reversed sense of test ---------+---+
            #                                      |   |
            #                                      v   v
            return ( $self->$not_name()->count ) ? 0 : 1 ;
        };
    }

    my $update_with = $p->update_with;

    if ( $update_with ) {
        method $update_with => sub {
            my ( $self, $status, @rest ) = @_;

            foreach my $item ( $self->all ) {
                $item->$update_with( $status, @rest );
            }

            # allow chaining
            return $self;
        };
    }
};

1;
