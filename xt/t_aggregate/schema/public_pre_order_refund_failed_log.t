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
        moniker   => 'Public::PreOrderRefundFailedLog',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                pre_order_refund_id
                preauth_ref_used
                failure_message
                operator_id
                date
            ]
        ],

        relations => [
            qw[
                pre_order_refund
                operator
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                  order_by_id
                  order_by_id_desc
            ]
        ],
    }
);

$schematest->run_tests();
