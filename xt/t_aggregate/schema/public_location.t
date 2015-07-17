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
        moniker   => 'Public::Location',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                location
            ]
        ],

        relations => [
            qw[
                channel_transfer_picks
                channel_transfer_putaways
                location_allowed_statuses
                log_locations
                putaways
                quantities
                shipment_items
                stock_count_variants
                rtv_quantities
                channel_transfer_picks
                product_variants
                voucher_variants
                stock_processes
                allowed_statuses
                sample_request_type_bookout_location_ids
                sample_request_type_source_location_ids
                putaway_prep_containers
                prls
            ]
        ],

        custom => [
            qw[
                allows_status
                is_on_floor
            ]
        ],

        resultsets => [
            qw[
                get_location
                get_iws_location
                location_allows_status
                get_locations
            ]
        ],
    }
);

$schematest->run_tests();
