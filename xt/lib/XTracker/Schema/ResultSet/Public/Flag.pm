package XTracker::Schema::ResultSet::Public::Flag;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head2 by_description

    $result_set = $self->by_description;

Returns a resultset of all Flags in Description order,

=cut

sub by_description {
    my $self    = shift;

    return $self->search( {}, { order_by => 'description' } );
}


1;
