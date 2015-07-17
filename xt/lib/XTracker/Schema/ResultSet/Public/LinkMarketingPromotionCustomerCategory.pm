package XTracker::Schema::ResultSet::Public::LinkMarketingPromotionCustomerCategory;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
use DateTime;

use Moose;
with 'XTracker::Schema::Role::ResultSet::LinkMarketingPromotion' => {
    included_and_order_by => {
        name              => 'customer_category',
        plural            => 'customer_categories',
        description_field => 'category',
    },
};

1;
