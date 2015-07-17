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
        moniker   => 'Public::ProductType',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                product_type
            ]
        ],

        relations => [
            qw[
                product_type_measurements
                sample_product_type_default_sizes
                measurements
                product_type_tax_rates
                link_marketing_promotion__product_types
                std_size_mappings
                products
                promotion_detail_producttypes
            ]
        ],

        custom => [
            qw[
                small_labels_per_item_override
                large_labels_per_item_override
                measurements_for_channels
            ]
        ],

        resultsets => [
            qw[
                producttype_list
            ]
        ],
    }
);

$schematest->run_tests();
