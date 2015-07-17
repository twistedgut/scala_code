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
        moniker   => 'Public::Language',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                code
                description
            ]
        ],
        resultsets => [
            qw[
                get_language_from_code
                get_default_language_preference
                get_all_language_codes
                get_all_languages_and_default
            ]
        ],
        custom => [
            qw[
            ]
        ],
        relations => [
            qw[
                customer_attributes
                orders
                language__promotion_types
                link_marketing_promotion__languages
            ]
        ]
    }
);

$schematest->run_tests();

