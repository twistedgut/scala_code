package XTracker::Schema::ResultSet::Public::Department;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Carp;

use base 'DBIx::Class::ResultSet';

__PACKAGE__->load_components(qw{Helper::ResultSet::SetOperations});

=head2 customer_care_group

    my $array_ref   = $department->customer_care_group;

Returns a list of Department Records which are part of the Customer Care Group.

=cut

sub customer_care_group {
    my ( $self )    = @_;

    my @group   = grep { $_->is_in_customer_care_group } ( $self->search( {}, { order_by => 'id' } )->all );

    return ( wantarray ? @group : \@group );
}

1;
