#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::CustomerActionType',
        glue      => 'Result',
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
                customer_actions
            ]
        ],

        custom => [
            qw[
            ],
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
