package PWS::Schema::StandardisedSize;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Data::Dump qw(pp);

use base 'DBIx::Class';
__PACKAGE__->load_components('PK::Auto', 'Core');
__PACKAGE__->table('standardised_size');

__PACKAGE__->add_columns(
    id => {
        data_type       => 'integer',
    },
    sizing_group => {
    },
    standardised_size => {
    },
    rank => {
    },
);

__PACKAGE__->set_primary_key('id');
#__PACKAGE__->resultset_class('PWS::ResultSet::StandardisedSize');

1;
