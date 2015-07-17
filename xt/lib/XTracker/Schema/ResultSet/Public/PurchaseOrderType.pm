package XTracker::Schema::ResultSet::Public::PurchaseOrderType;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head2 drop_down_options

Returns a resultset of all designers ordered for display in a select drop-down-box.
For now it returns in 'id' order

=cut

sub drop_down_options {
    my ( $class ) = @_;

    return $class->search({}, {order_by=> 'id'} );
}


sub po_types {
    my $self = shift;
    my $me = $self->current_source_alias;

    return $self->search_rs( {},
        {
            order_by => "$me.id",
            cache => 1,
        },
    );
}

1;
