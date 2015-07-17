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
        moniker   => 'Public::ProductAttribute',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                product_id
                name
                description
                long_description
                short_description
                designer_colour
                editors_comments
                keywords
                recommended
                designer_colour_code
                size_scheme_id
                custom_lists
                act_id
                pre_order
                operator_id
                id
                sample_correct
                sample_colour_correct
                product_department_id
                fit_notes
                style_notes
                editorial_approved
                use_measurements
                editorial_notes
                outfit_links
                use_fit_notes
                size_fit
                related_facts
                runway_look
            ]
        ],

        relations => [
            qw[
                product_department
                size_scheme
                product
                act
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
