package XTracker::Schema::ResultSet::Promotion::CouponGeneration;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub action_list {
    my $resultset = shift;

    my $list = $resultset->search(
        {
        },
        {
            order_by => ['idx DESC'],
        },
    );

    return $list;
}

1;
