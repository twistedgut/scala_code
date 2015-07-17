#!/usr/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

# load the module that provides all of the common test functionality
use FindBin::libs;

use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::MarketingPromotion',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                title
                channel_id
                description
                start_date
                end_date
                enabled
                is_sent_once
                message
                created_date
                operator_id
                promotion_type_id
            ]
        ],

        relations => [
            qw[
                channel
                link_marketing_promotion__designers
                link_marketing_promotion__customer_segments
                link_orders__marketing_promotions
                marketing_promotion_logs
                operator
                promotion_type
                link_marketing_promotion__product_types
                link_marketing_promotion__countries
                link_marketing_promotion__languages
                link_marketing_promotion__gender_proxies
                link_marketing_promotion__customer_categories
            ]
        ],

        custom => [
            qw[
                has_designers_assigned
                can_designers_be_applied_to_order
                has_countries_assigned
                can_countries_be_applied_to_order
                has_languages_assigned
                can_languages_be_applied_to_order
                has_product_types_assigned
                can_product_types_be_applied_to_order
                has_gender_titles_assigned
                can_gender_titles_be_applied_to_order
                has_customer_categories_assigned
                can_customer_categories_be_applied_to_order
                is_weighted
                assign_designers
                reassign_designers
                assign_customer_segments
                reassign_customer_segments
                assign_countries
                reassign_countries
                assign_languages
                reassign_languages
                assign_product_types
                reassign_product_types
                assign_gender_titles
                reassign_gender_titles
                assign_customer_categories
                reassign_customer_categories
                _assign_option_to_promotion
            ]
        ],

        resultsets => [
            qw[
                get_enabled_promotion_by_channel
                get_disabled_promotion_by_channel
                get_active_promotions_by_channel
                _get_promotion_list
            ]
        ],
    }
);

$schematest->run_tests();
