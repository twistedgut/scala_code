#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker => 'SystemConfig::ParameterType',
        glue => 'Result',
    }
);

$schematest->methods(
    {
        columns => [
            qw[
                id
                type
            ]
        ],

        relations => [
            qw[
                parameters
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
