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
        moniker   => 'Public::LanguagePromotionType',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                language_id
                promotion_type_id
            ]
        ],
        resultsets => [
            qw[
            ]
        ],
        custom => [
            qw[
            ]
        ],
        relations => [
            qw[
                language
                promotion_type
            ]
        ]
    }
);

$schematest->run_tests();

