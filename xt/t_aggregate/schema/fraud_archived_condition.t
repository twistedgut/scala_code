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
        moniker   => 'Fraud::ArchivedCondition',
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
                change_log_id
                created
                created_by_operator_id
                expired
                expired_by_operator_id
            ]
        ],

        relations => [
            qw[
                change_log
                conditional_operator
                method
                rule
                created_by_operator
                expired_by_operator
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
