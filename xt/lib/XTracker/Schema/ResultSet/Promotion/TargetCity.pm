package XTracker::Schema::ResultSet::Promotion::TargetCity;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub targetcity_list {
    my $resultset = shift;

    my $list = $resultset->search(
        {
        },
        {
            order_by => ['display_order ASC, name ASC'],
            cache => 1,
        },
    );

    return $list;
}

1;
