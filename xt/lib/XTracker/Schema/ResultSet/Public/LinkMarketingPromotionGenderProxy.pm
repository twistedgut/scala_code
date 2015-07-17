package XTracker::Schema::ResultSet::Public::LinkMarketingPromotionGenderProxy;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
use DateTime;

use Moose;
with 'XTracker::Schema::Role::ResultSet::LinkMarketingPromotion' => {
    included_and_order_by => {
        name      => 'title',
        plural    => 'titles',
        join_name => 'gender_proxy',
    },
};

1;
