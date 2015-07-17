package XTracker::Schema::ResultSet::Public::LinkMarketingPromotionCountry;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
use DateTime;

use Moose;
with 'XTracker::Schema::Role::ResultSet::LinkMarketingPromotion' => {
    included_and_order_by => {
        name   => 'country',
        plural => 'countries',
    },
};

1;
