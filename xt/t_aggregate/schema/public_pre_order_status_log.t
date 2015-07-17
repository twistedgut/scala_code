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
        moniker   => 'Public::PreOrderStatusLog',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                pre_order_id
                pre_order_status_id
                operator_id
                date
            ]
        ],

        relations => [
            qw[
                pre_order
                pre_order_status
                operator
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                  status_log_for_summary_page
                  order_by_id
                  order_by_id_desc
                  order_by_date
                  order_by_date_desc
                  order_by_date_id
                  order_by_date_id_desc
            ]
        ],
    }
);

$schematest->run_tests();
