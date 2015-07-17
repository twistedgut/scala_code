package Analysis::Schema;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base qw/DBIx::Class::Schema/;

__PACKAGE__->load_classes(qw/Query Request/);

1;
