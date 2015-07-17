package PWS::Schema::Coupon;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Data::Dump qw(pp);

use base 'DBIx::Class';
__PACKAGE__->load_components('PK::Auto', 'Core');
__PACKAGE__->table('coupon');

__PACKAGE__->add_columns(
    'id' => {
        data_type       => 'integer',
    },

    prefix              => {},
    suffix              => {},
    code                => {},
    restrict_by_email   => {},
    email               => {},
    customer_id         => {},
    usage_limit         => {},
    usage_type_id       => {},
    usage_count         => {},
    valid               => {},
    event_id            => {},
);

__PACKAGE__->set_primary_key('id');
#__PACKAGE__->resultset_class('XTracker::ResultSet::Coupon');

__PACKAGE__->belongs_to(
    'usage_type'  => 'CouponRestrictionGroup',
    { 'foreign.id' => 'self.group_id' }
);

1;
