package PWS::Schema::Customer;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Data::Dump qw(pp);

use base 'DBIx::Class';
__PACKAGE__->load_components('PK::Auto', 'Core');
__PACKAGE__->table('customer');

__PACKAGE__->add_columns(
    qw(
        id
        email
    )
);

__PACKAGE__->set_primary_key('id');

1;
