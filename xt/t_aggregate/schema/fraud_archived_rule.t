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
        moniker   => 'Fraud::ArchivedRule',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                channel_id
                rule_sequence
                name
                start_date
                end_date
                enabled
                action_order_status_id
                metric_used
                metric_decided
                change_log_id
                created
                created_by_operator_id
                expired
                expired_by_operator_id
                tag_list
            ]
        ],

        relations => [
            qw[
                change_log
                archived_conditions
                orders_rule_outcomes
                live_rules
                channel
                action_order_status
                created_by_operator
                expired_by_operator
            ]
        ],

        custom => [
            qw[
                textualise
                conditions
                process_rule
                increment_metric
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
