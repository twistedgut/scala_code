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
        moniker   => 'Public::ProductChannel',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                product_id
                channel_id
                live
                staging
                visible
                disable_update
                cancelled
                arrival_date
                upload_date
                transfer_status_id
                transfer_date
                pws_sort_adjust_id
            ]
        ],

        relations => [
            qw[
                channel
                product
                recommended_product_children
                recommended_product_parents
                recommendations
                recommended_with
                stock_summary
            ]
        ],

        custom => [
            qw[
                is_first_arrival
                uploading_soon
                get_recommended_with_live_products
            ]
        ],

        resultsets => [
            qw[
                pids_live_on_channel
                list_on_channel_for_upload_date
            ]
        ],
    }
);

$schematest->run_tests();
