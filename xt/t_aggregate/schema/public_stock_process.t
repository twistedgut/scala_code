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
        moniker   => 'Public::StockProcess',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                delivery_item_id
                quantity
                group_id
                type_id
                status_id
                complete
                container
                putaway_type_id
                last_updated
            ]
        ],

        relations => [
            qw[
                putaways
                type
                status
                delivery_item
                stock_process_group
                putaway_type
                rtv_stock_process
                log_putaway_discrepancies
            ]
        ],

        custom => [
            qw[
                variant
                split_stock_process
                add_to_quantity
                remove_from_quantity
                complete_stock_process
                get_group
                putaway_complete
                get_voucher
                leftover
                mark_as_putaway
                mark_qcfaulty_voucher
                stock_status_for_putaway
                is_handled_by_iws
                is_handled_by_prl
                is_new
                is_approved
                is_bagged_and_tagged
                is_main
                is_dead
                is_surplus
                is_quarantine_fixed
                is_fasttrack
                is_faulty
                pre_advice_sent_but_not_putaway
                return_item
                send_to_main
                send_to_dead
                send_to_rtv
                send_to_rtv_customer_repair
            ]
        ],

        resultsets => [
            qw[
                log_putaway
                get_voucher
                get_group
                main
                faulty
                get_by_type
                pending_putaway
                pending_items
                total_quantity
                is_complete
                putaway_process_groups
                putaway_prep_process_groups
                get_process_groups
                generate_new_group_id
                bag_and_tag
            ]
        ],
    }
);

$schematest->run_tests();
