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
        moniker   => 'Public::CustomerAttribute',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                customer_id
                language_preference_id
            ]
        ],
        relations => [
            qw[
                customer
                language_preference
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
