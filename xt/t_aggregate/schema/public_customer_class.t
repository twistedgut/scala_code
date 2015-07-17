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
        moniker   => 'Public::CustomerClass',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                class
                is_visible
            ]
        ],

        relations => [
            qw[
                customer_categories
            ]
        ],

        custom => [
            qw[
                is_finance_high_priority
            ]
        ],

        resultsets => [
            qw[
                get_classes
                get_finance_high_priority_classes
                add_class
                edit_class_name
                hide_class
            ]
        ],
    }
);

$schematest->run_tests();

