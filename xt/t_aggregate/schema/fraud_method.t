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
        moniker   => 'Fraud::Method',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                description
                object_to_use
                method_to_call
                method_parameters
                return_value_type_id
                rule_action_helper_method
                processing_cost
                list_type_id
            ]
        ],

        relations => [
            qw[
                archived_conditions
                live_conditions
                staging_conditions
                return_value_type
                list_type
            ]
        ],

        custom => [
            qw[
                get_allowable_values_from_helper
                get_an_allowable_value_from_helper
                is_boolean
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
