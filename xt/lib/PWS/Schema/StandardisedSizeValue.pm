package PWS::Schema::StandardisedSizeValue;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Data::Dump qw(pp);

use base 'DBIx::Class';
__PACKAGE__->load_components('PK::Auto', 'Core');
__PACKAGE__->table('standardised_size_value');

__PACKAGE__->add_columns(
    standardised_size_id => {
        data_type       => 'integer',
    },
    size_value => {
    },
);

__PACKAGE__->set_primary_key('standardised_size_id');
#__PACKAGE__->resultset_class('PWS::ResultSet::StandardisedSizeValue');

1;
