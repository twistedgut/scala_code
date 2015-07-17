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
        moniker   => 'Public::ShipmentBox',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                shipment_id
                box_id
                tracking_number
                inner_box_id
                outward_box_label_image
                return_box_label_image
                tote_id
                hide_from_iws
                last_updated
            ]
        ],

        relations => [
            qw[
                inner_box
                box
                shipment
                shipment_items
                shipment_box_logs
            ]
        ],

        custom => [
            qw[
                outer_box
                package_weight
                threshold_package_weight
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
