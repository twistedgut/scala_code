package PWS::Schema::CouponTarget;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Data::Dump qw(pp);

use base 'DBIx::Class';
__PACKAGE__->load_components('PK::Auto', 'Core');
__PACKAGE__->table('coupon_target');

__PACKAGE__->add_columns(
    'id' => {
        data_type       => 'integer',
    },

    description => {},
);

__PACKAGE__->set_primary_key('id');
#__PACKAGE__->resultset_class('PWS::ResultSet::CouponTarget');

1;

# XXX do we use this at all?
