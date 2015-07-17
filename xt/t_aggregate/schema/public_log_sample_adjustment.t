#!/usr/bin/env perl

use strict;
use warnings;

use FindBin::libs;

use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from    => 'xtracker',
        namespace   => 'XTracker::Schema',
        moniker     => 'Public::LogSampleAdjustment',
        glue        => 'Result',
    }
);

$schematest->methods(
    {
        columns => [
            qw[
                id
                sku
                location_name
                operator_name
                channel_id
                notes
                delta
                balance
                timestamp
            ]
        ],

        relations => [
            qw[
                channel
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                data_for_log_screen
            ]
        ],
    }
);

$schematest->run_tests();
