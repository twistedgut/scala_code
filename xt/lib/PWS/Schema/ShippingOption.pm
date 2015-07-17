package PWS::Schema::ShippingOption;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Data::Dump qw(pp);

use base 'DBIx::Class';
__PACKAGE__->load_components('PK::Auto', 'Core');
__PACKAGE__->table('shipping_option');

__PACKAGE__->add_columns(
    id => {
        data_type       => 'integer',
    },
    name => {
    },
);

__PACKAGE__->set_primary_key('id');
#__PACKAGE__->resultset_class('PWS::ResultSet::ShippingOption');

__PACKAGE__->has_many(
    detail_shippingoptions => 'PWS::Schema::DetailShippingOptions',
    'shippingoption_id'
);

__PACKAGE__->many_to_many(
    shippingoptions => 'detail_shippingoptions' => 'detail'
);

1;
