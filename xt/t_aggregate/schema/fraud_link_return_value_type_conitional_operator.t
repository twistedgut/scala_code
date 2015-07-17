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
        moniker   => 'Fraud::LinkReturnValueTypeConditionalOperator',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                return_value_type_id
                conditional_operator_id
            ]
        ],

        relations => [
            qw[
                conditional_operator
                return_value_type
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
