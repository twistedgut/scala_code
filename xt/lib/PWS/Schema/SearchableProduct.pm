package PWS::Schema::SearchableProduct;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class';
__PACKAGE__->load_components('PK::Auto', 'Core');
__PACKAGE__->table('searchable_product');

__PACKAGE__->add_columns(
    # this list is far from complete, but we currently only use the table to
    # see if a product exists
    qw<
        id
        title
    >
);

__PACKAGE__->set_primary_key('id');

1;
