#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::CustomerAction',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                customer_id
                operator_id
                customer_action_type_id
                date_created
            ]
        ],

        relations => [
            qw[
                customer
                operator
                customer_action_type
            ]
        ],

        custom => [
            qw[
            ],
        ],

        resultsets => [
            qw[
                get_new_high_values
                add_customer_new_high_value
            ]
        ],
    }
);

$schematest->run_tests();
