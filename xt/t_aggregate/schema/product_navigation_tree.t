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
        moniker   => 'Product::NavigationTree',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                attribute_id
                parent_id
                sort_order
                visible
                deleted
                feature_product_id
                feature_product_image
            ]
        ],

        relations => [
            qw[
                attribute
                attribute_parent
                child_tree
                parent_tree
                navigation_tree_locks
                log_navigation_trees
                child_trees
                feature_product
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
