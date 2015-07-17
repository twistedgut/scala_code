package XTracker::Schema::ResultSet::Promotion::DetailCustomerGroupJoin;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub customer_group_join_list {
    my $resultset = shift;

    my $list = $resultset->search(
        {
        },
        {
            order_by => ['type ASC'],
        },
    );

    return $list;

}

1;
