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
        moniker   => 'Public::CustomerCategory',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                category
                discount
                is_visible
                customer_class_id
                fast_track
            ]
        ],

        relations => [
            qw[
                customers
                customer_class
                customer_category_defaults
                link_marketing_promotion__customer_categories
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                get_categories
                add_category
                edit_category_name
                change_class
                hide_category
                hide_category_by_class
                get_category_by_id
            ]
        ],
    }
);

$schematest->run_tests();

