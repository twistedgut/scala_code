package XTracker::Schema::ResultSet::Public::LinkMarketingPromotionLanguage;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
use DateTime;

use Moose;
with 'XTracker::Schema::Role::ResultSet::LinkMarketingPromotion' => {
    included_and_order_by => {
        name              => 'language',
        plural            => 'languages',
        description_field => 'description',
    },
};

1;
