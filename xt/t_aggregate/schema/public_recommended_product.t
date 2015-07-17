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
        moniker   => 'Public::RecommendedProduct',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                product_id
                recommended_product_id
                type_id
                sort_order
                slot
                approved
                auto_set
                channel_id
            ]
        ],

        relations => [
            qw[
                channel
                product
                recommended_product
                type
                product_channel
                recommended_product_channel
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                get_recommendations
                get_colour_variations
            ]
        ],
    }
);

$schematest->run_tests();
