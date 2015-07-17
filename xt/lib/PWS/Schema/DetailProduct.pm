package PWS::Schema::DetailProduct;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Data::Dump qw(pp);

use base 'DBIx::Class';
__PACKAGE__->load_components('PK::Auto', 'Core');
__PACKAGE__->table('event_product');

__PACKAGE__->add_columns(
    'id' => {
        data_type       => 'integer',
    },
    event_id => {
    },
    product_id => {
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_unique_constraint(
    'join_data' => [qw/event_id product_id/]
);

__PACKAGE__->belongs_to(
    detail => 'PWS::Schema::Detail',
    { 'foreign.id' => 'self.event_id' }
);

1;
