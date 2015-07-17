package XTracker::Schema::ResultSet::Public::LinkMarketingPromotionDesigner;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
use DateTime;

use Moose;
with 'XTracker::Schema::Role::ResultSet::LinkMarketingPromotion' => {
    included_and_order_by => {
        name    => 'designer',
        plural  => 'designers',
    },
};

1;
