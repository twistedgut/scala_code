package XTracker::Schema::ResultSet::Promotion::CustomerGroup;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub customer_group_list {
    my $resultset = shift;

    my $list = $resultset->search(
        {
        },
        {
            order_by => ['name ASC'],
            cache => 1,
        },
    );

    return $list;
}

1;
