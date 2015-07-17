package XTracker::Schema::ResultSet::Promotion::Website;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

# this returns the websites we'd like to show for "NAP events"
sub site_list {
    my $resultset = shift;

    my $list = $resultset->search(
        {
            # don't show outnet sites in the UI
            'me.name' => { 'NOT LIKE' => q{OUT-%} },
        },
        {
            order_by => ['name DESC'],
        },
    );

    return $list;
}

# this returns the websites we'd like to show for "NAP events"
sub event_site_list {
    my $resultset = shift;

    my $list = $resultset->search(
        {
            # only show outnet sites in the UI
            'me.name' => { 'LIKE' => q{OUT-%} },
        },
        {
            order_by => ['name DESC'],
        },
    );

    return $list;
}

1;
