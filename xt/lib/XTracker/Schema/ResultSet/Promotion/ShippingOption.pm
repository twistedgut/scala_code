package XTracker::Schema::ResultSet::Promotion::ShippingOption;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub shippingoption_list {
    my $resultset = shift;

    my $list = $resultset->search(
        {
        },
        {
            order_by => ['name ASC'],
        },
    );

    return $list;
}

1;
