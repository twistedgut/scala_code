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
        moniker   => 'Fraud::LiveCondition',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                rule_id
                method_id
                conditional_operator_id
                value
                enabled
            ]
        ],

        relations => [
            qw[
                conditional_operator
                method
                rule
            ]
        ],

        custom => [
            qw[
                textualise
                compile
                evaluate
            ]
        ],

        resultsets => [
            qw[
                by_processing_cost
                enabled
            ]
        ],
    }
);

$schematest->run_tests();
