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
        moniker   => 'Public::ReservationStatus',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                status
            ]
        ],

        relations => [
            qw[
                reservations
                reservation_operator_logs
                reservation_logs
                reservation_auto_change_log_post_status_ids
                reservation_auto_change_log_pre_status_ids
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                non_uploaded
            ]
        ],
    }
);

$schematest->run_tests();
