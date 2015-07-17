package XTracker::Schema::ResultSet::Public::Putaway;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head1 NAME

XTracker::Schema::ResultSet::Public::Putaway

=head1 METHODS

=head2 incomplete

Returns incomplete putaway items

=cut

sub incomplete {
    my ( $self ) = @_;
    my $me = $self->current_source_alias;
    return $self->search({"$me.complete"=>0});
}

=head2 total_quantity

Returns the sum of the quantity fields of the items in this rs.

=cut

sub total_quantity {
    return $_[0]->get_column('quantity')->sum || 0;
}

1;
