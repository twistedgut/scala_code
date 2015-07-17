#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker => 'SystemConfig::Parameter',
        glue => 'Result',
    }
);

$schematest->methods(
    {
        columns => [
            qw[
                id
                parameter_group_id
                parameter_type_id
                name
                description
                value
                sort_order
            ]
        ],

        relations => [
            qw[
                parameter_type
                parameter_group
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
