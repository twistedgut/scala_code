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
        moniker   => 'Public::PromotionType',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                name
                product_type
                weight
                fabric
                origin
                hs_code
                promotion_class_id
                channel_id
            ]
        ],

        relations => [
            qw[
                country_promotion_type_welcome_packs
                order_promotions
                promotion_class
                channel
                countries
                marketing_promotions
                language__promotion_types
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                search_by_ilike_name
            ]
        ],
    }
);

$schematest->run_tests();
