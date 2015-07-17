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
        moniker   => 'Public::RoutingSchedule',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                routing_schedule_type_id
                routing_schedule_status_id
                external_id
                date_imported
                task_window_date
                task_window
                driver
                run_number
                run_order_number
                signatory
                signature_time
                undelivered_notes
                notified
            ]
        ],

        relations => [
            qw[
                link_routing_schedule__return
                link_routing_schedule__shipment
                routing_schedule_type
                routing_schedule_status
                shipments
                returns
            ]
        ],

        custom => [
            qw[
                shipment_rec
                return_rec
                format_task_window
            ],
            'twelve_hour',          # imported from 'XTracker::Utilities::DBIC::DateTimeFormat'
        ],

        resultsets => [
            qw[
                list_schedules
            ]
        ],
    }
);

$schematest->run_tests();

