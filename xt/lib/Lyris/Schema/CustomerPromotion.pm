package Lyris::Schema::CustomerPromotion;

use strict;
use warnings;
use Data::Dump qw(pp);

use base 'DBIx::Class';
__PACKAGE__->load_components('PK::Auto', 'Core');
__PACKAGE__->table('customer_promotion');

__PACKAGE__->add_columns(
    'promotion_number', {
        data_type       => 'varchar',
        is_nullable     => 0,
    },
    'customer_id', {
        data_type       => 'integer',
        is_nullable     => 0,
    },
    'coupon_code', {
        data_type       => 'varchar',
        default_value   => undef,
        is_nullable     => 1,
    },
);
__PACKAGE__->set_primary_key( qw/ promotion_number customer_id / );


1;
