package XTracker::Schema::ResultSet::Promotion::PriceGroup;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub pricegroup_list {
    my $resultset = shift;

    my $list = $resultset->search(
        {
        },
        {
            order_by => ['description ASC'],
        },
    );

    return $list;
}

1;
