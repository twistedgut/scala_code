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
        moniker   => 'Fraud::LiveRule',
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
                archived_rule_id
                tag_list
            ]
        ],

        relations => [
            qw[
                live_conditions
                archived_rule
                staging_rules
                channel
                action_order_status
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
                get_active_rules_for_channel
                by_sequence
                process_rules_for_channel
            ]
        ],
    }
);

$schematest->run_tests();
