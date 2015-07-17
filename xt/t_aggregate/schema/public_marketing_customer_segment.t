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
        moniker   => 'Public::MarketingCustomerSegment',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                name
                channel_id
                enabled
                created_date
                operator_id
                job_queue_flag
                date_of_last_jq
            ]
        ],

        relations => [
            qw[
                channel
                link_marketing_customer_segment__customers
                link_marketing_promotion__customer_segments
                marketing_customer_segment_logs
                operator
            ]
        ],

        custom => [
            qw [
                get_customer_count
            ],
        ],

        resultsets => [
            qw[
                get_enabled_customer_segment_by_channel
                get_disabled_customer_segment_by_channel
                is_unique
                get_segment_list
                search_by_name
            ]
        ],
    }
);

$schematest->run_tests();
