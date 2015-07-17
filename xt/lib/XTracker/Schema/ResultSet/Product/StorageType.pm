package XTracker::Schema::ResultSet::Product::StorageType;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub get_options {
    return shift->search(
                    {},
                    {'order_by' => 'id'},
                );
}


sub by_name {
    my ($self, $name) = @_;
    # we have "oversize" that should match "oversized"...
    return $self->find({ name => {-ilike => "$name%" }});
}
1;
