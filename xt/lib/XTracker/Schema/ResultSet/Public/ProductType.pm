package XTracker::Schema::ResultSet::Public::ProductType;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub producttype_list {
    my $resultset = shift;

    my $list = $resultset->search(
        {
        },
        {
            order_by => ['product_type ASC'],
            cache => 1,
        },
    );

    return $list;
}

1;
