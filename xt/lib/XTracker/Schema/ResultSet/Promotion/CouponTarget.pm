package XTracker::Schema::ResultSet::Promotion::CouponTarget;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub coupontarget_list {
    my $resultset = shift;

    my $list = $resultset->search(
        {
        },
        {
            order_by => ['id ASC'],
        },
    );

    return $list;
}

1;
