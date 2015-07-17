package PWS::Schema::Detail;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Data::Dump qw(pp);
use DateTime::Format::MySQL;

use base 'DBIx::Class';
__PACKAGE__->load_components('PK::Auto', 'Core');
__PACKAGE__->table('event_detail');

__PACKAGE__->add_columns(
qw<
    id
    created
    created_by
    last_modified
    last_modified_by
    visible_id
    internal_title
    start_date
    end_date
    target_city_id
    enabled
    discount_type
    discount_percentage
    discount_pounds
    discount_euros
    discount_dollars
    coupon_prefix
    coupon_target_id
    coupon_restriction_id
    coupon_generation_id
    price_group_id
    basket_trigger_pounds
    basket_trigger_euros
    basket_trigger_dollars
    title
    subtitle
    status_id
    been_exported
    exported_to_lyris
    restrict_by_weeks
    restrict_x_weeks
    coupon_custom_limit
    event_type_id
    publish_method_id
    publish_date
    announce_date
    close_date
    publish_to_announce_visibility
    announce_to_start_visibility
    start_to_end_visibility
    end_to_close_visibility
    target_value
    target_currency
    product_page_visible
    end_price_drop_date
    description
    dont_miss_out
    sponsor_id
    is_classic
>

);

__PACKAGE__->set_primary_key('id');
#__PACKAGE__->resultset_class('PWS::ResultSet::Detail');

__PACKAGE__->add_unique_constraint(
    unique_title => [ qw/internal_title/ ],
);

foreach my $datecol (qw/start_date end_date/) {
    __PACKAGE__->inflate_column($datecol, {
        inflate => sub { DateTime::Format::MySQL->parse_datetime(shift); },
        deflate => sub { DateTime::Format::MySQL->format_datetime(shift); },
    });
}


__PACKAGE__->belongs_to(
    'coupon_restriction'  => 'CouponRestriction',
    { 'foreign.id' => 'self.coupon_restriction_id' }
);

#
## Custom Record-Level Methods
#

1;
