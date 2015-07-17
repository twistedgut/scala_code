package XTracker::Promotion::Common;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Perl6::Export::Attrs;

sub construct_left_nav :Export {
    my ($handler) = @_;

    # yes this should be done differently!
    # yes, we should push on extras as we need them!
    if ($handler->{data}{is_manager} or $handler->{data}{is_operator}) {
        $handler->{data}{sidenav} = [
            {   'Promotion' => [
                    {   'title' => 'Summary',
                        'url'   => '/NAPEvents/Manage',
                    },
                    {   'title' => 'Create',
                        'url'   => '/NAPEvents/Manage/Create',
                    },
                    {   'title' => 'Customer Groups',
                        'url'   => '/NAPEvents/Manage/CustomerGroups',
                    },
                ],
            },
        ];
    }
    else {
        $handler->{data}{sidenav} = [
            {   'Promotion' => [
                    {   'title' => 'Summary',
                        'url'   => '/NAPEvents/Manage',
                    },
                ],
            },
        ];
    }
}

1;