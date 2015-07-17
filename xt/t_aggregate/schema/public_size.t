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
        moniker   => 'Public::Size',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                size
                sequence
            ]
        ],

        relations => [
            qw[
                sample_classification_default_sizes
                sample_product_type_default_sizes
                sample_size_scheme_default_sizes
                size_scheme_variant_size_size_ids
                size_scheme_variant_size_designer_size_ids
                variant_size_ids
                variant_designer_size_ids
                us_size_mappings
                std_size_mappings
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
