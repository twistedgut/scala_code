package XTracker::Schema::ResultSet::Public::LinkMarketingPromotionProductType;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
use DateTime;

use Moose;
with 'XTracker::Schema::Role::ResultSet::LinkMarketingPromotion' => {
    included_and_order_by => {
        name   => 'product_type',
        plural => 'product_types',
    },
};

1;
