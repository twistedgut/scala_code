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
        moniker   => 'Public::PreOrderRefund',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                pre_order_id
                pre_order_refund_status_id
                sent_to_psp
            ]
        ],

        relations => [
            qw[
                pre_order
                pre_order_refund_failed_logs
                pre_order_refund_items
                pre_order_refund_status
                pre_order_refund_status_logs
            ]
        ],

        custom => [
            qw[
                  is_failed
                  is_pending
                  is_cancelled
                  is_complete
                  is_refundable
                  update_status
                  total_value
                  clear_sent_to_psp_flag
                  set_sent_to_psp_flag
                  mark_as_failed_via_psp
                  refund_to_customer
                  most_recent_failed_log
            ]
        ],

        resultsets => [
            qw[
                  failed
                  pending
                  cancelled
                  complete
                  not_failed
                  not_pending
                  not_cancelled
                  not_complete
                  are_all_failed
                  are_all_pending
                  are_all_cancelled
                  are_all_complete
                  order_by_id
                  order_by_id_desc
            ]
        ],
    }
);

$schematest->run_tests();
