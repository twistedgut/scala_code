package Patcher::Schema;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::Schema';

# we only want to load ONE table
__PACKAGE__->load_classes(
    {
        'XTracker::Schema::Result'  => [qw/ DBAdmin::AppliedPatch /],
    }
);

1;
