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
        moniker   => 'Public::Box',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                box
                weight
                volumetric_weight
                active
                length
                width
                height
                label_id
                channel_id
                is_conveyable
                requires_tote
                sort_order
            ]
        ],

        relations => [
            qw[
                channel
                carrier_box_weights
                inner_boxes
                shipment_boxes
                shipping_attributes
            ]
        ],

        custom => [
            qw[
                cubic_volume
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();
