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
        moniker   => 'Public::LogDelivery',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                delivery_id
                type_id
                delivery_action_id
                operator_id
                quantity
                notes
                date
            ]
        ],

        relations => [
            qw[
                delivery
                type
                delivery_action
                operator
                stock_process_type
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                order_for_log
            ]
        ],
    }
);

$schematest->run_tests();
